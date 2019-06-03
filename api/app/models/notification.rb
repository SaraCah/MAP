RecordNotifications = Struct.new(:record_type, :record_id, :identifier, :notifications) do
  def to_json(*args)
    to_h.to_json
  end
end

Notification = Struct.new(:message, :level) do
  def to_json(*args)
    to_h.to_json
  end
end
