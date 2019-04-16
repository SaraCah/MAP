require 'set'

class Indexer

  INDEX_DELAY_SECONDS = AppConfig[:indexer_delay_seconds]
  WINDOW_MS = AppConfig[:indexer_window_milliseconds]

  BATCH_SIZE = AppConfig[:indexer_batch_size]

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
      "record_type" => "agent_corporate_entity",
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
      false
    end
  end

  def send_deletes(deletes)
    if deletes.length > 0
      uri = URI.join(@solr_url, 'update')

      $LOG.info("Deleting #{deletes.length} document(s)")

      request = Net::HTTP::Post.new(uri)

      request['Content-Type'] = 'application/json'
      request.body = JSON.dump(deletes.map {|id| {"id" => id}})

      Net::HTTP.start(uri.host, uri.port) do |http|
        response = http.request(request)
        raise "Indexing error: #{response.body}" unless response.code == '200'
      end

      deletes.clear

      true
    else
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

        agent_corporate_entities(db, last_mtime) do |agent|
          batch << prepare_agent_corporate(agent)
          if batch.length >= BATCH_SIZE
            needs_commit |= send_batch(batch)
          end
        end

        needs_commit |= send_batch(batch)

        # Handle deletes
        delete_batch = []

        db[:deleted_records]
          .filter(Sequel[:deleted_records][:timestamp] >= Time.at(last_mtime / 1000))
          .filter(Sequel.like(:uri, '/agents/corporate_entities/%'))
          .select(:uri)
          .each do |row|
          delete_batch << "agent_corporate_entity:%s" % [row[:uri].split('/')[3]]

          if delete_batch.length >= BATCH_SIZE
            needs_commit |= send_deletes(delete_batch)
          end
        end

        needs_commit |= send_deletes(delete_batch)

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

  def agent_corporate_entities(aspace_db, last_mtime)
    aspace_db[:agent_corporate_entity]
      .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
      .filter(Sequel[:name_corporate_entity][:authorized] => 1)
      .filter(Sequel[:agent_corporate_entity][:system_mtime] >= Time.at(last_mtime / 1000))
      .select(Sequel[:agent_corporate_entity][:id],
              Sequel[:name_corporate_entity][:sort_name])
      .each do |agent|
      yield agent
    end
  end

  def call
    loop do
      index_loop
    end
  end

end
