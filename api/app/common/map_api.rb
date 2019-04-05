class MapAPI

  def self.base_dir(rest)
    File.absolute_path(File.join(File.dirname(__FILE__), "../../", rest))
  end

end
