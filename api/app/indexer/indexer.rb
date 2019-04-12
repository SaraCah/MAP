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

  def prepare_agent_corporate(row, ancestor_ids)
    {
      "id" => "agent_corporate_entity:#{row[:id]}",
      "aspace_id" => row[:id].to_s,
      "display_string" => row[:sort_name],
      "keywords" => row[:sort_name],
      "record_type" => "agent_corporate_entity",
      "ancestor_ids" => ancestor_ids.map {|id| "agent_corporate_entity:#{id}"},
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

        walk_agency_tree(db, last_mtime) do |agent, ancestor_ids|
          batch << prepare_agent_corporate(agent, ancestor_ids)
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

    return if paths_to_root.empty?

    loop do
      # paths_to_root
      require 'pp';$stderr.puts("\n*** DEBUG #{(Time.now.to_f * 1000).to_i} [indexer.rb:141 f8f285]: " + {%Q^paths_to_root^ => paths_to_root}.pretty_inspect + "\n")

      relns = db[:series_system_rlshp]
                .join(:enumeration_value, Sequel[:series_system_rlshp][:relator_id] => Sequel[:enumeration_value][:id])
                .filter(:jsonmodel_type => 'series_system_agent_agent_containment_relationship')
                .filter(Sequel.|({:agent_corporate_entity_id_0 => paths_to_root.map(&:last)},
                                 {:agent_corporate_entity_id_1 => paths_to_root.map(&:last)}))
                .filter(:end_date => nil)
                .select(Sequel.as(:agent_corporate_entity_id_0, :left),
                        Sequel.as(:agent_corporate_entity_id_1, :right),
                        Sequel.as(:relationship_target_id, :target),
                        Sequel.as(Sequel[:enumeration_value][:value], :relator))

      progressed = false
      relns.each do |row|
        (parent_id, child_id) = if row[:relator] == 'is_contained_within'
                                  parent_id = row[:target]
                                  child_id = ([row[:left], row[:right]] - [parent_id]).first
                                  [parent_id, child_id]
                                else
                                  child_id = row[:target]
                                  parent_id = ([row[:left], row[:right]] - [child_id]).first
                                  [parent_id, child_id]
                                end

        paths_to_root.each do |path|
          if path.last == child_id
            if path.include?(parent_id)
              # Cycle
            else
              path << parent_id
              progressed = true
            end
          end
        end
      end

      break unless progressed
    end

    # walk all agency trees from the root agency

    paths_from_root = paths_to_root.map {|path| [path.last]}
    100.times do
      to_process = paths_from_root.map(&:last)

      # Yield the agents seen so far
      db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => to_process)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name])
        .each do |agent|
        yield [agent, paths_from_root.find {|path| path.last == agent[:id]}.clone]
      end

      # Find the next layer of children
      relns = db[:series_system_rlshp]
                .join(:enumeration_value, Sequel[:series_system_rlshp][:relator_id] => Sequel[:enumeration_value][:id])
                .filter(:jsonmodel_type => 'series_system_agent_agent_containment_relationship')
                .filter(Sequel.|({:agent_corporate_entity_id_0 => to_process},
                                 {:agent_corporate_entity_id_1 => to_process}))
                .filter(:end_date => nil)
                .select(Sequel.as(:agent_corporate_entity_id_0, :left),
                        Sequel.as(:agent_corporate_entity_id_1, :right),
                        Sequel.as(:relationship_target_id, :target),
                        Sequel.as(Sequel[:enumeration_value][:value], :relator))

      progressed = false
      relns.each do |row|
        (parent_id, child_id) = if row[:relator] == 'is_contained_within'
                                  parent_id = row[:target]
                                  child_id = ([row[:left], row[:right]] - [parent_id]).first
                                  [parent_id, child_id]
                                else
                                  child_id = row[:target]
                                  parent_id = ([row[:left], row[:right]] - [child_id]).first
                                  [parent_id, child_id]
                                end

        paths_from_root.each do |path|
          if path.last == parent_id
            if path.include?(child_id)
              # Cycle.  Ignore.
            else
              progressed = true
              path << child_id
            end
          end
        end
      end

      break unless progressed
    end
  end

  def call
    loop do
      index_loop
    end
  end

end
