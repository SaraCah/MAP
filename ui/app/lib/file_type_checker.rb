require File.join(Dir.pwd, '../distlibs/tika-core.jar')

class FileTypeChecker

  def self.check(upload_files)
    extension_disjunction = Regexp.union(AppConfig[:file_upload_allowed_extensions].map {|ext| Regexp.quote(ext)})
    extension_pattern = /\.#{extension_disjunction}\Z/

    tika = org.apache.tika.Tika.new

    failures = upload_files.reject {|file|
      (file.tmp_file.path.downcase =~ extension_pattern) && tika_accepts?(tika, file.tmp_file.path)
    }

    failures
  end

  def self.self_test!
    tika = org.apache.tika.Tika.new
    unless tika.detect("something") == 'application/octet-stream'
      raise "Apache Tika doesn't seem to be working!  Please check file_type_checker.rb"
    end
  end

  def self.tika_accepts?(tika, path)
    # Note: we'll use an InputStream here because by default Tika pays
    # attention to the file extension if all else fails, and we don't trust
    # the file extension.
    io = java.io.FileInputStream.new(path)

    begin
      mime_type = HTTPUtils.sanitise_mime_type(tika.detect(io))
      # Tika uses ooxml for MS Office docs; text/plain for CSV/TSV.  Allow those.
      if mime_type != 'application/x-tika-ooxml' &&
         mime_type != 'text/plain' &&
         !AppConfig[:file_upload_allowed_mime_types].include?(mime_type)
        $LOG.info("Tika rejecting file claiming MIME type '%s': detected as '%s'" %
                  [file.mime_type, mime_type])
        false
      else
        true
      end
    ensure
      io.close
    end
  end

end


# Validate the Tika is looking good when we start up
FileTypeChecker.self_test!
