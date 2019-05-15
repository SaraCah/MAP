require 'zlib'

RECORD_BATCH_SIZE = 25

class SolrIndexer

  def initialize
    @solr_url = AppConfig[:solr_url]

    unless @solr_url.end_with?('/')
      @solr_url += '/'
    end

    @state_file = AppConfig[:solr_indexer_state_file]
    FileUtils.mkdir_p(File.dirname(@state_file))
  end

  def call
    loop do
      begin
        run_index_round
      rescue
        $LOG.error("Error caught in SolrIndexer: #{$!}")
        $LOG.error($@.join("\n"))
      end

      sleep AppConfig[:map_indexer_interval_seconds]
    end
  end

  def run_index_round
    last_indexed_id = load_last_indexed_id

    needs_commit = false

    DB.open do |db|
      db[:index_feed].filter { id > last_indexed_id }.map(:id).sort.each_slice(RECORD_BATCH_SIZE) do |id_set|
        batch = []

        db[:index_feed].filter(:id => id_set).each do |row|
          batch << JSON.parse(ungzip(row[:blob]))
        end

        send_batch(batch)
        needs_commit = true

        last_indexed_id = id_set.last
      end
    end

    if needs_commit
      send_commit
    end

    save_last_indexed_id(last_indexed_id)
  end

  def self.start
    Thread.new do
      SolrIndexer.new.call
    end
  end

  private

  def load_last_indexed_id
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

  def save_last_indexed_id(new_value)
    tmp = "#{@state_file}.tmp.#{SecureRandom.hex}"
    File.write(tmp, new_value.to_s)
    File.rename(tmp, @state_file)
  end


  def ungzip(bytestring)
    Zlib::Inflate.inflate(bytestring)
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

  # Not used yet, but we'll need it soon
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



end
