class UploadFile

  attr_reader :filename, :mime_type, :tmp_file

  def initialize(filename, mime_type, tmp_file)
    @filename = filename
    @mime_type = mime_type
    @tmp_file = tmp_file
  end

  def to_io
    Rack::Multipart::UploadedFile.new(@tmp_file.path, @mime_type)
  end

  def self.parse(param)
    # FIXME check size limit (MediumBlob-esque)
    new(param['filename'], param['type'], param['tempfile'])
  end

end
