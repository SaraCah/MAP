class Files < BaseStorage

  def self.store(io)
    key = SecureRandom.hex
    db[:file].insert(key: key, blob: Sequel::SQL::Blob.new(io.read))

    key
  end

end
