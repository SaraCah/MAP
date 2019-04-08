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
    File.write("#{@state_file}.tmp", ms_since_epoch.to_s)
    File.rename("#{@state_file}.tmp", @state_file)
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

      $stderr.puts("Sending #{batch.length} documents to #{uri}")

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
      $stderr.puts("Sending nothing...")

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

        db[:agent_corporate_entity]
          .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
          .filter(Sequel[:name_corporate_entity][:authorized] => 1)
          .select(Sequel[:agent_corporate_entity][:id],
                  Sequel[:name_corporate_entity][:sort_name])
          .filter(Sequel[:agent_corporate_entity][:system_mtime] >= Time.at(last_mtime / 1000))
          .each do |agent|
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
      $stderr.puts("Error in indexer: #{$!}")
      $stderr.puts($@.join("\n"))
    end

    sleep INDEX_DELAY_SECONDS
  end

  def call
    loop do
      index_loop
    end
  end

end
