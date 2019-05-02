class TransferProposalSeries
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:series_title, String)
  define_field(:disposal_class, String, required: false)
  define_field(:date_range, String, required: false)
  define_field(:accrual_details, String, required: false)
  define_field(:creating_agency, String, required: false)
  define_field(:mandate, String, required: false)
  define_field(:function, String, required: false)
  define_field(:system_of_arrangement, String, required: false)
  define_field(:composition_digital, Boolean, default: false)
  define_field(:composition_physical, Boolean, default: false)
  define_field(:composition_hybrid, Boolean, default: false)


  def self.from_row(row)
    new(id: row[:id],
        series_title: row[:series_title],
        disposal_class: row[:disposal_class],
        date_range: row[:date_range],
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