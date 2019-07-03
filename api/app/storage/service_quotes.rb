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

  def self.chargeable_services(services = ['File Issue Physical', 'File Issue Digital', 'Search Request'])
    service_by_id = {}

    AspaceDB.open do |aspace_db|
      aspace_db[:chargeable_service]
        .join(:chargeable_service_item_rlshp, Sequel[:chargeable_service_item_rlshp][:chargeable_service_id] => Sequel[:chargeable_service][:id])
        .join(:chargeable_item, Sequel[:chargeable_item][:id] => Sequel[:chargeable_service_item_rlshp][:chargeable_item_id])
        .join(Sequel.as(:enumeration, :charge_quantity_unit_enum), Sequel[:charge_quantity_unit_enum][:name] => 'runcorn_charge_quantity_unit')
        .join(Sequel.as(:enumeration_value, :charge_quantity_unit_enum_value),
              Sequel.&(Sequel[:charge_quantity_unit_enum][:id] => Sequel[:charge_quantity_unit_enum_value][:enumeration_id],
                       Sequel[:charge_quantity_unit_enum_value][:id] => Sequel[:chargeable_item][:charge_quantity_unit_id]))
        .filter(Sequel[:chargeable_service][:name] => services)
        .order(Sequel[:chargeable_service_item_rlshp][:chargeable_service_id], Sequel[:chargeable_service_item_rlshp][:aspace_relationship_position])
        .select(
          Sequel.as(Sequel[:chargeable_service][:id], :chargeable_service_id),
          Sequel.as(Sequel[:chargeable_service][:name], :chargeable_service_name),
          Sequel.as(Sequel[:chargeable_service][:description], :chargeable_service_description),
          Sequel.as(Sequel[:chargeable_service][:last_revised_statement], :chargeable_service_last_revised_statement),
          Sequel.as(Sequel[:chargeable_item][:id], :chargeable_item_id),
          Sequel.as(Sequel[:chargeable_item][:name], :chargeable_item_name),
          Sequel.as(Sequel[:chargeable_item][:description], :chargeable_item_description),
          Sequel.as(Sequel[:chargeable_item][:price_cents], :chargeable_item_price_cents),
          Sequel.as(Sequel[:charge_quantity_unit_enum_value][:value], :chargeable_item_charge_unit))
        .map do |row|
        service_by_id[row[:chargeable_service_id]] ||= ChargeableService.new(row[:chargeable_service_id],
                                                                             row[:chargeable_service_name],
                                                                             row[:chargeable_service_description],
                                                                             row[:chargeable_service_last_revised_statement], [])
        service_by_id[row[:chargeable_service_id]].items << ChargeableItem.new(row[:chargeable_item_id],
                                                                               row[:chargeable_item_name],
                                                                               row[:chargeable_item_description],
                                                                               row[:chargeable_item_price_cents],
                                                                               row[:chargeable_item_charge_unit])
      end
    end

    service_by_id.values
  end

end
