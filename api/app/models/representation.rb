Representation = Struct.new(:uri, :series_id, :record_id, :title, :start_date, :end_date, :representation_id, :agency_assigned_id, :previous_system_id, :format, :file_issue_allowed, :intended_use, :other_restrictions, :processing_notes) do
  def to_json(*args)
    to_h.to_json
  end
end