require_relative '../app/storage/db_connection'
require_relative '../app/storage/aspace_db'

Sequel.migration do
  AspaceDB.connect
  up do
    AspaceDB.open do |aspace_db|
      self[:file_issue_item].each do |fi|
        updates = {}
        [:dispatched_by, :received_by].each do |fld|
          unless fi[fld].nil?
            agent_id = aspace_db[:user].filter(:name => fi[fld]).get(:agent_record_id) || 1
            updates[fld] = "/agents/people/#{agent_id}"
          end
        end

        unless updates.empty?
          self[:file_issue_item].filter(:id => fi[:id]).update(updates)
        end
      end
    end
  end
end
