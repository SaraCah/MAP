class DB

  def self.connect
    @pool = DBPool.new.connect
    @connected = true
  end

  def self.open(opts = {})
    raise "Not connected" unless @connected

    transaction = opts.fetch(:transaction, true)

    begin
      last_err = false
      retries = opts.fetch(:retries, 10)

      retries.times do |attempt|
        begin
          if transaction
            @pool.transaction(isolation: opts.fetch(:isolation_level, :repeatable)) do |db|
              return yield db
            end

            # Sometimes we'll make it to here.  That means we threw a
            # Sequel::Rollback which has been quietly caught.
            return nil
          else
            begin
              return yield @pool.pool
            rescue Sequel::Rollback
              # If we're not in a transaction we can't roll back, but no need to blow up.
              Log.warn("Sequel::Rollback caught but we're not inside of a transaction")
              return nil
            end
          end
        rescue Sequel::DatabaseDisconnectError => e
          # MySQL might have been restarted.
          last_err = e
          Log.info("Connecting to the database failed.  Retrying...")
          sleep(opts[:db_failed_retry_delay] || 3)


        rescue Sequel::NoExistingObject, Sequel::DatabaseError => e
          if (attempt + 1) < retries && is_retriable_exception(e, opts) && transaction
            Log.info("Retrying transaction after retriable exception (#{e})")
            sleep(opts[:retry_delay] || 1)
          else
            raise e
          end
        end
      end

      if last_err
        Log.error("Failed to connect to the database")
        Log.exception(last_err)

        raise "Failed to connect to the database: #{last_err}"
      end
    end
  end

  # Yeesh.
  def self.is_integrity_violation(exception)
    (exception.wrapped_exception.cause or exception.wrapped_exception).getSQLState() =~ /^23/
  end


  def self.is_retriable_exception(exception, opts = {})
    # Transaction was rolled back, but we can retry
    ((opts[:retry_on_optimistic_locking_fail] &&
      exception.instance_of?(Sequel::Plugins::OptimisticLocking::Error)) ||
     (exception.wrapped_exception && ( exception.wrapped_exception.cause or exception.wrapped_exception).getSQLState() =~ /^(40|41)/) )
  end


  class MarkTheBastard

    def info(msg)
      if Thread.current[:db_query_excluded]
        return
      end

      Thread.current[:db_query_count] ||= 0
      Thread.current[:db_query_time] ||= 0.0

      if msg =~ /SELECT|UPDATE|INSERT|DELETE/
        Thread.current[:db_query_count] += 1
        Thread.current[:db_query_time] += Float(msg[1..msg.index("s") - 1])
      end
    end

    def self.with_exclusion
      excl = Thread.current[:db_query_excluded]
      Thread.current[:db_query_excluded] = true
      begin
        yield
      ensure
        Thread.current[:db_query_excluded] = excl
      end
    end

    def self.query_count
      result = Thread.current[:db_query_count] || 0
      Thread.current[:db_query_count] = 0
      result
    end

    def self.query_time
      result = Thread.current[:db_query_time] || 0.0
      Thread.current[:db_query_time] = 0.0
      (result * 1000).to_i
    end

    def method_missing(*)
    end

  end


  class DBPool

    attr_reader :pool

    def initialize(pool_size = AppConfig[:db_max_connections], opts = {})
      @pool_size = pool_size
      @opts = opts
      @pool = nil
    end

    def connect
      return if @pool

      begin
        @pool = Sequel.connect(AppConfig[:db_url],
                               max_connections: @pool_size,
                               test: true,
                               loggers: (AppConfig[:db_debug_log] ? [Logger.new($stderr), MarkTheBastard.new] : [MarkTheBastard.new]))

        self
      rescue
        Log.error("DB connection failed: #{$!}")
      end
    end

    def transaction(*args)
      @pool.transaction(*args) do
        yield(@pool)
      end
    end
  end
end
