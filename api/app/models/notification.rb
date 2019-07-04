Notification = Struct.new(:record_type, :record_id, :identifier, :message, :level, :timestamp, :agency_ref) do
  def to_json(*args)
    to_h.to_json
  end
end

module Notifications
  NOTIFICATION_WINDOW = 7 # days
end
