class MAPEnumSource

  def values_for(enum)
    AspaceDB.open do |aspace_db|
      aspace_db[:enumeration]
        .join(:enumeration_value, Sequel.qualify(:enumeration, :id) => Sequel.qualify(:enumeration_value, :enumeration_id))
        .filter(Sequel.qualify(:enumeration, :name) => enum.to_s)
        .select(Sequel.qualify(:enumeration_value, :value))
        .order(Sequel.qualify(:enumeration_value, :position))
        .map(:value)
    end
  end

end
