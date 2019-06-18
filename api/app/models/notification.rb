Notification = Struct.new(:record_type, :record_id, :identifier, :message, :level, :timestamp) do
  def to_json(*args)
    to_h.to_json
  end
end

