class TransferProposalSeries
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:series_title, String, validator: proc {|s| (s.length > 0) ? nil : "Title can't be blank" })
  define_field(:description, String, validator: proc {|s| (s.length > 0) ? nil : "Description can't be blank" })
  define_field(:disposal_class, String, validator: proc {|s| (s.length > 0) ? nil : "Disposal Class can't be blank" })
  define_field(:date_range, String, validator: proc {|s| (s.length > 0) ? nil : "Date Range can't be blank" })
  define_field(:accrual, Boolean, default: false)
  define_field(:accrual_details, String, required: false)
  define_field(:creating_agency, String, required: false)
  define_field(:mandate, String, required: false)
  define_field(:function, String, required: false)
  define_field(:system_of_arrangement, String, validator: proc {|s| (s.length > 0) ? nil : "System of Arrangement can't be blank" })
  define_field(:composition_digital, Boolean, default: false)
  define_field(:composition_physical, Boolean, default: false)
  define_field(:composition_hybrid, Boolean, default: false)


  def self.from_row(row)
    new(id: row[:id],
        series_title: row[:series_title],
        description: row[:description],
        disposal_class: row[:disposal_class],
        date_range: row[:date_range],
        accrual: (row[:accrual] == 1),
        accrual_details: row[:accrual_details],
        creating_agency: row[:creating_agency],
        mandate: row[:mandate],
        function: row[:function],
        system_of_arrangement: row[:system_of_arrangement],
        composition_digital: (row[:composition_digital] == 1),
        composition_physical: (row[:composition_physical] == 1),
        composition_hybrid: (row[:composition_hybrid] == 1))
  end
end