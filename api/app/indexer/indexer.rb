class Indexer

  # FIXME: AppConfig
  INDEX_DELAY_SECONDS = 5
  WINDOW_MS = 180000

  BATCH_SIZE = 100

  def self.start(solr_url, state_file)
    Thread.new do
      Indexer.new(solr_url, state_file).call
    end
  end

  def initialize(solr_url, state_file)
    @solr_url = solr_url

    unless @solr_url.end_with?('/')
      @solr_url += '/'
    end

    @state_file = state_file

    FileUtils.mkdir_p(File.dirname(state_file))
  end

  def load_last_mtime
    if File.exist?(@state_file)
      begin
        Integer(File.read(@state_file))
      rescue
        0
      end
    else
      0
    end
  end

  def save_last_mtime(ms_since_epoch)
    tmp = "#{@state_file}.tmp.#{SecureRandom.hex}"
    File.write(tmp, ms_since_epoch.to_s)
    File.rename(tmp, @state_file)
  end

  def prepare_agent_corporate(row)
    {
      "id" => "agent_corporate_entity:#{row[:id]}",
      "aspace_id" => row[:id].to_s,
      "display_string" => row[:sort_name],
      "keywords" => row[:sort_name],
      "record_type" => "agent_corporate_entity"
    }
  end

  def send_batch(batch)
    if batch.length > 0
      uri = URI.join(@solr_url, 'update')

      $LOG.info("Sending #{batch.length} documents to #{uri}")

      request = Net::HTTP::Post.new(uri)

      request['Content-Type'] = 'application/json'
      request.body = JSON.dump(batch)

      Net::HTTP.start(uri.host, uri.port) do |http|
        response = http.request(request)
        raise "Indexing error: #{response.body}" unless response.code == '200'
      end

      batch.clear

      true
    else
      $LOG.info("Sending nothing...")

      false
    end
  end

  def send_commit
    uri = URI.join(@solr_url, 'update')
    request = Net::HTTP::Post.new(uri)

    request['Content-Type'] = 'application/json'
    request.body = JSON.dump({:commit => {"softCommit" => false}})

    Net::HTTP.start(uri.host, uri.port) do |http|
      response = http.request(request)
      raise "Commit failed: #{response.body}" unless response.code == '200'
    end
  end

  def index_loop
    begin
      last_mtime = load_last_mtime
      now = java.lang.System.currentTimeMillis - WINDOW_MS

      needs_commit = false

      AspaceDB.open do |db|
        batch = []

        walk_agency_tree(db, last_mtime) do |agent|
          batch << prepare_agent_corporate(agent)
          if batch.length >= BATCH_SIZE
            needs_commit = send_batch(batch) || needs_commit
          end
        end

        needs_commit = send_batch(batch) || needs_commit

        send_commit if needs_commit
      end

      save_last_mtime(now)
    rescue
      # FIXME: Logging
      $LOG.info("Error in indexer: #{$!}")
      $LOG.info($@.join("\n"))
    end

    sleep INDEX_DELAY_SECONDS
  end

  def walk_agency_tree(db, last_mtime)
    # calculate the root of each agency tree
    paths_to_root = db[:agent_corporate_entity]
                      .filter(Sequel[:agent_corporate_entity][:system_mtime] >= Time.at(last_mtime / 1000))
                      .map{|row| [row[:id]]}

    completed_paths = []

    while(true) do
      relns = db[:series_system_rlshp]
                .filter(:jsonmodel_type => 'series_system_agent_agent_containment_relationship')
                .filter(:agent_corporate_entity_id_1 => paths_to_root.map(&:last))
                .filter(Sequel.~(:end_date => nil))
                .select(Sequel.as(:agent_corporate_entity_id_0, :parent),
                        Sequel.as(:agent_corporate_entity_id_1, :child))

      break if relns.empty?

      relns.each do |row|
        paths_to_root.each do |path|
          if path.last == row[:child]
            if path.include?(row[:parent])
              completed_paths << path
            else
              path << row[:parent]
            end
          end
        end
        paths_to_root -= completed_paths
      end
    end

    completed_paths.concat(paths_to_root)

    # walk all agency trees from the root agency
    processed_ids = []
    left_to_process = completed_paths.map(&:last)
    while(!left_to_process.empty?) do
      db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => left_to_process)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name])
        .each do |agent|

        yield(agent)

        processed_ids << agent[:id]
      end

      children_to_process = []
      db[:series_system_rlshp]
        .filter(:jsonmodel_type => 'series_system_agent_agent_containment_relationship')
        .filter(:agent_corporate_entity_id_0 => left_to_process)
        .filter(Sequel.~(:end_date => nil))
        .select(Sequel.as(:agent_corporate_entity_id_1, :child))
        .each do |row|
        children_to_process << row[:child]
      end

      left_to_process = children_to_process - processed_ids
    end
  end

  def call
    loop do
      index_loop
    end
  end

end
