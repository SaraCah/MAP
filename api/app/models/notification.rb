Notification = Struct.new(:record_type, :record_id, :identifier, :message, :level) do
  def to_json(*args)
    to_h.to_json
  end
end