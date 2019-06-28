class ServiceQuotes < BaseStorage

  def self.get_quote(quote_id)
    result = nil

    AspaceDB.open do |aspace_db|
      quote_row = aspace_db[:service_quote][id: quote_id]

      if quote_row[:issued_date]
        quote = ServiceQuote.new(quote_row[:id], quote_row[:issued_date], 0, []) #FIXME total amount

        aspace_db[:service_quote_line]
          .join(Sequel.as(:enumeration, :charge_quantity_unit_enum), Sequel[:charge_quantity_unit_enum][:name] => 'runcorn_charge_quantity_unit')
          .join(Sequel.as(:enumeration_value, :charge_quantity_unit_enum_value),
                Sequel.&(Sequel[:charge_quantity_unit_enum][:id] => Sequel[:charge_quantity_unit_enum_value][:enumeration_id],
                         Sequel[:charge_quantity_unit_enum_value][:id] => Sequel[:service_quote_line][:charge_quantity_unit_id]))
          .filter(service_quote_id: quote_id)
          .select(
            Sequel.as(Sequel[:service_quote_line][:description], :description),
            Sequel.as(Sequel[:service_quote_line][:quantity], :quantity),
            Sequel.as(Sequel[:service_quote_line][:charge_per_unit_cents], :charge_per_unit_cents),
            Sequel.as(Sequel[:charge_quantity_unit_enum_value][:value], :charge_quantity_unit))
          .order(Sequel[:service_quote_line][:id])
          .map do |line_item_row|
          quote.line_items << ServiceQuoteLineItem.new(line_item_row[:description],
                                                       line_item_row[:quantity],
                                                       line_item_row[:charge_per_unit_cents],
                                                       line_item_row[:charge_quantity_unit],
                                                       line_item_row[:quantity].to_i * line_item_row[:charge_per_unit_cents].to_i) # FIXME pull this from ASpace?
          quote.total_charge_cents += line_item_row[:quantity].to_i * line_item_row[:charge_per_unit_cents].to_i # FIXME pull this from ASpace?
        end

        result = quote
      end
    end

    result
  end

end
