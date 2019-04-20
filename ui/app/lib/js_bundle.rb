require 'tempfile'

class JSBundle

  def self.bundle_configuration
    @config ||= {}
  end

  def self.add_to_bundle(bundle, module_name, file)
    self.bundle_configuration[bundle] ||= []
    self.bundle_configuration[bundle] << {
      module_name: module_name,
      file: file,
    }
  end

  # Emit a RequireJS-compatible bundle definition for our configuration.
  def self.requirejs_bundle_defs
    self.bundle_configuration.map {|bundle_name, defs|
      [bundle_name, defs.map {|d| d[:module_name]}]
    }.to_h.to_json
  end

  def self.has_bundle?(name)
    self.bundle_configuration.keys.find {|bundle| "#{bundle}.js" == name}
  end

  def self.filename_for_bundle(name)
    bundle_name = File.basename(name, ".js")
    if MAPTheApp.development? && @bundle_files.include?(bundle_name)
      # Force a rebuild so we're not seeing cached versions.
      @bundle_files.delete(bundle_name).close
      init
    end

    @bundle_files.fetch(bundle_name).path
  end

  def self.init
    @bundle_files ||= {}

    self.bundle_configuration.each do |bundle, defs|
      unless @bundle_files[bundle]
        @bundle_files[bundle] = Tempfile.new([bundle, '.js'])
        out = @bundle_files[bundle]

        defs.each do |bundle_def|
          saw_lf = false
          File.open(bundle_def[:file], 'r') do |fh|
            while (chunk = fh.read(4096))
              out.write(chunk)
              saw_lf = chunk.end_with?("\n")
            end
          end

          unless saw_lf
            # Ensure we don't run our scripts together.
            out.write("\n")
          end
        end

        out.flush
      end
    end
  end
end
