class Utils
  def self.hash_keys_to_strings(hash)
    hash.map {|k, v| [k.to_s, v]}.to_h
  end
end
