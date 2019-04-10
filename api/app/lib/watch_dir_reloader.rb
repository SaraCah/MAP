class WatchDirReloader

  def initialize(dirs)
    @dirs = dirs.map {|f| File.absolute_path(f)}
  end

  def start
    Thread.new do
      watcher = java.nio.file.FileSystems.getDefault().newWatchService()
      watch_keys = {}

      @dirs.each do |dir|
        dir = java.nio.file.Paths.get(dir)

        key = dir.register(watcher, java.nio.file.StandardWatchEventKinds::ENTRY_MODIFY)
        watch_keys[key] = dir
      end

      loop do
        key = watcher.take

        key.poll_events.each do |event|
          path_to_reload = watch_keys[key].resolve(event.context).to_string

          begin
            load path_to_reload
          rescue
            $LOG.info("Failed to reload path: #{path_to_reload}")
          end
        end

        unless key.reset
          raise "Key reset failed"
        end
      end
    end
  end

end
