require 'logger'

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
              $stderr.puts("Sequel::Rollback caught but we're not inside of a transaction")
              return nil
            end
          end
        rescue Sequel::DatabaseDisconnectError => e
          # MySQL might have been restarted.
          last_err = e
          $stderr.puts("Connecting to the database failed.  Retrying...")
          sleep(opts[:db_failed_retry_delay] || 3)


        rescue Sequel::NoExistingObject, Sequel::DatabaseError => e
          if (attempt + 1) < retries && is_retriable_exception(e, opts) && transaction
            $stderr.puts("Retrying transaction after retriable exception (#{e})")
            sleep(opts[:retry_delay] || 1)
          else
            raise e
          end
        end
      end

      if last_err
        $stderr.puts("Failed to connect to the database")

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
                               loggers: Logger.new($stderr))

        self
      rescue
        $stderr.puts("DB connection failed: #{$!}")
      end
    end

    def transaction(*args)
      @pool.transaction(*args) do
        yield(@pool)
      end
    end
  end
end
