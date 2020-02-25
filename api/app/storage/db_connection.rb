class DBConnection

  def initialize(db_url)
    @pool = DBPool.new(db_url)
    @pool.connect
    @connected = true
  end

  def open(opts = {})
    raise "Not connected" unless @connected

    transaction = opts.fetch(:transaction, true)

    begin
      last_err = false
      retries = opts.fetch(:retries, 100)

      retries.times do |attempt|
        begin
          if transaction
            result = nil
            @pool.transaction(isolation: opts.fetch(:isolation_level, :repeatable),
                              rollback: opts.fetch(:rollback, nil)) do |db|
              result = yield db
              result
            end

            # Sometimes we'll make it to here.  That means we threw a
            # Sequel::Rollback which has been quietly caught.
            return result
          else
            begin
              return yield @pool.pool
            rescue Sequel::Rollback
              # If we're not in a transaction we can't roll back, but no need to blow up.
              $LOG.info("Sequel::Rollback caught but we're not inside of a transaction")
              return nil
            end
          end
        rescue Sequel::DatabaseDisconnectError, Sequel::DatabaseConnectionError => e
          # MySQL might have been restarted.
          last_err = e
          $LOG.info("Connecting to the database failed.  Retrying...")
          sleep(opts[:db_failed_retry_delay] || 0.5)


        rescue Sequel::NoExistingObject, Sequel::DatabaseError => e
          if (attempt + 1) < retries && is_retriable_exception(e, opts) && transaction
            $LOG.info("Retrying transaction after retriable exception (#{e})")
            sleep(opts[:retry_delay] || 0.2)
          else
            raise e
          end
        end
      end

      if last_err
        $LOG.info("Failed to connect to the database")

        raise "Failed to connect to the database: #{last_err}"
      end
    end
  end

  def is_retriable_exception(exception, opts = {})
    # Transaction was rolled back, but we can retry
    return true if (opts[:retry_on_optimistic_locking_fail] && exception.instance_of?(Sequel::Plugins::OptimisticLocking::Error))
    return true if (exception.wrapped_exception && exception.wrapped_exception.class == java.net.SocketException)

    wrapped_exception = (exception.wrapped_exception.cause or exception.wrapped_exception)

    # < means "subclass of in this context..."
    return true if wrapped_exception.class < java.sql.SQLRecoverableException

    # Connection failures (SQL_STATE_COMMUNICATION_LINK_FAILURE)
    return true if (wrapped_exception.class == java.sql.SQLException && wrapped_exception.getSQLState() =~ /^80/)

    # Deadlocks
    return true if (wrapped_exception.class == java.sql.SQLException && wrapped_exception.getSQLState() =~ /^(40|41)/)

    return false
  end

  class DBPool
    # If RDS fails over we're going to get a message like this.  Do our best to reconnect.
    DATABASE_READ_ONLY_REGEX = /is read only|server is running with the --read-only option/

    attr_reader :pool

    def initialize(db_url, pool_size = AppConfig[:db_max_connections], opts = {})
      @db_url = db_url
      @pool_size = pool_size
      @opts = opts
      @pool = nil

      @lock = Mutex.new
    end

    def connect
      return if @pool

      begin
        @pool = Sequel.connect(@db_url,
                               max_connections: @pool_size,
                               test: true,
                               loggers: AppConfig[:enable_db_logging] ? $LOG : [])

        @pool = @pool.extension(:pagination)

        self
      rescue
        $LOG.info("DB connection failed: #{$!}")
        raise
      end
    end

    def transaction(*args)
      retry_count = 0

      begin
        # @pool might be nil if we're in the middle of a reconnect.  Spin for a
        # bit before giving up.
        pool = nil

        60.times do
          pool = @pool
          break if pool
          sleep 1
        end

        if pool.nil?
          $LOG.info("DB connection failed: unable to get a connection")
          raise
        end

        pool.transaction(*args) do
          yield(pool)
        end
      rescue Sequel::DatabaseError => e
        $LOG.warn("DB connection failure: #{e}.  Retry count is #{retry_count}")

        if retry_count > 6
          # We give up
          raise e
        end

        if e.to_s =~ DATABASE_READ_ONLY_REGEX
          sleep rand * 10

          # Reset the pool...
          old_pool = @pool

          @lock.synchronize do
            if @pool == old_pool
              # If we got the lock and nobody has reset the pool yet, it's time to do our thing.
              @pool = nil

              # We retry the connection indefinitely here.  The system isn't
              # going to function until the pool is restored, so either return
              # successful or don't return at all.
              begin
                connect
              rescue
                $LOG.warn("DB connection failure on reconnect: #{$!}.  Retrying indefinitely...")
                sleep 1
                retry
              end
            end
          end

          retry_count += 1
          retry
        else
          raise e
        end

      end
    end
  end


end
