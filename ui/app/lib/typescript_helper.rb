TYPESCRIPT_DEV_LOG = File.join('..', '.typescript_last_output.txt')

class TypescriptHelper
  def self.error_report
    return nil unless MAPTheApp.development?

    error_log = File.read(TYPESCRIPT_DEV_LOG) rescue ''

    if error_log =~ /: error TS/
      error_log
    else
      nil
    end
  end
end
