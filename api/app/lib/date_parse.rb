require 'date'

class DateParse

  def self.date_parse_down(s)
    return nil if s.nil?

    begin
      return Date.strptime(s, '%Y-%m-%d')
    rescue ArgumentError
      begin
        return Date.strptime(s, '%Y-%m')
      rescue ArgumentError
        begin
          return Date.strptime(s, '%Y')
        rescue
          return nil
        end
      end
    end
  end


  def self.date_parse_up(s)
    return nil if s.nil?

    begin
      return Date.strptime(s, '%Y-%m-%d')
    rescue ArgumentError
      begin
        month = Date.strptime(s, '%Y-%m')
        return month.next_month - 1
      rescue ArgumentError
        begin
          year = Date.strptime(s, '%Y')
          return year.next_year - 1
        rescue
          return nil
        end
      end
    end
  end



end
