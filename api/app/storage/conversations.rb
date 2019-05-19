class Conversations < BaseStorage

  RECORD_TYPE_TO_COLUMN = {
    :transfer => :handle_id,
  }

  def self.messages_for(handle_id)
    db[:conversation]
      .filter(:handle_id => handle_id)
      .order(:id)
      .map do |row|
      ConversationMessage.from_row(row)
    end
  end

  def self.create(handle_id, message)
    db[:conversation]
      .insert(handle_id: handle_id,
              message: message,
              created_by: Ctx.username,
              create_time: java.lang.System.currentTimeMillis)
  end


end
