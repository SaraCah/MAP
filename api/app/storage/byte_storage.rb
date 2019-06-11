class ByteStorage

  def self.get
    if AppConfig.has_key?(:storage_s3_bucket)
      S3AuthenticatedStorage.new
    elsif AppConfig.has_key?(:storage_file_path)
      FileStorage.new(AppConfig[:storage_file_path])
    elsif AppConfig.has_key?(:storage_s3_url)
      S3Storage.new(AppConfig[:storage_s3_url])
    else
      raise "Config needs either :storage_s3_bucket, :storage_file_path or :storage_s3_url"
    end
  end

end
