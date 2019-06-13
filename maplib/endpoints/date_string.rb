class DateString

  VALID_DATE = Regexp.union(/[0-9]{4}-[0-9]{2}-[0-9]{2}/,
                            /[0-9]{4}-[0-9]{2}/,
                            /[0-9]{4}/)

  def self.parse(s)
    if s =~ VALID_DATE
      s
    else
      raise ArgumentError.new("Date was not well-formed: #{s}")
    end
  end

end
