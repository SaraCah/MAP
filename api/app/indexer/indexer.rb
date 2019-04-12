require 'set'

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

        walk_agency_tree(db, last_mtime) do |agent, ancestor_ids|
          batch << prepare_agent_corporate(agent, ancestor_ids)
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

  def walk_agency_tree(aspace_db, last_mtime)
    ids_to_reindex = Set.new(aspace_db[:agent_corporate_entity]
                               .filter(Sequel[:agent_corporate_entity][:system_mtime] >= Time.at(last_mtime / 1000))
                               .map{|row| [row[:id]]})


    ids_to_reindex += aspace_db[:agency_descendant]
                        .filter(:agent_corporate_entity_id => ids_to_reindex.to_a)
                        .map(:descendant_id)

    ids_to_reindex = ids_to_reindex.to_a

    ancestors = aspace_db[:agency_ancestor]
                  .filter(:agent_corporate_entity_id => ids_to_reindex)
                  .reduce({}) do |groups, row|
      groups[row[:agent_corporate_entity_id]] ||= []
      groups[row[:agent_corporate_entity_id]] << row[:ancestor_id]
      groups
    end

    aspace_db[:agent_corporate_entity]
      .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
      .filter(Sequel[:name_corporate_entity][:authorized] => 1)
      .filter(Sequel[:agent_corporate_entity][:id] => ids_to_reindex)
      .select(Sequel[:agent_corporate_entity][:id],
              Sequel[:name_corporate_entity][:sort_name])
      .each do |agent|
      yield [agent, [agent[:id]] + ancestors.fetch(agent[:id], [])]
    end
  end

  def call
    loop do
      index_loop
    end
  end

end
