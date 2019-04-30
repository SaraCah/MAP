class UploadFile

  attr_reader :filename, :tmp_file

  def initialize(filename, tmp_file)
    @filename = filename
    @tmp_file = tmp_file
  end

  def to_io
    Rack::Multipart::UploadedFile.new(@tmp_file.path, @filename)
  end

  def self.parse(param)
    # FIXME check size limit (MediumBlob-esque)
    new(param['filename'], param['tempfile'])
  end

end