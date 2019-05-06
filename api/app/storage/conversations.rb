class Conversations < BaseStorage

  RECORD_TYPE_TO_COLUMN = {
    :transfer => :handle_id
  }

  def self.messages_for(record_type, id)
    db[:conversation]
      .filter(RECORD_TYPE_TO_COLUMN.fetch(record_type.intern) => id)
      .order(:id)
      .map do |row|
      ConversationMessage.from_row(row)
    end
  end

  def self.create(record_type, id, message)
    db[:conversation]
      .insert(RECORD_TYPE_TO_COLUMN.fetch(record_type.intern) => id,
              message: message,
              created_by: Ctx.username,
              create_time: java.lang.System.currentTimeMillis)
  end


end
