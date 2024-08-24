module Scheddy
  class Task
    attr_reader :cron, :delay, :interval, :name, :task, :tag, :track_runs, :type

    delegate :logger, to: :Scheddy


    def perform(scheduler, now: false)
      return next_cycle if Time.current < next_cycle && !now
      record_this_run
      if running?
        logger.error "Scheddy task '#{name}' already running; skipping this cycle"
        return next_cycle!
      end
      context = Context.new(scheduler, self)
      self.thread =
        Thread.new do
          logger.tagged tag do
            Rails.application.reloader.wrap do
              if context.finish_before < Time.current
                logger.info "Rails dev-mode reloader locked for entire task interval; skipping this run"
              else
                task.call(*[context].take(task.arity.abs))
              end
            rescue Exception => e
              Scheddy.handle_error(e, self)
            end
          end
        ensure
          self.thread = nil
        end
      next_cycle!
    rescue Exception => e
      logger.error "Scheddy: error scheduling task '#{name}'; retrying in 5 seconds"
      Scheddy.handle_error(e, self)
      return self.next_cycle = 5.seconds.from_now
    end

    def kill
      thread&.kill
    end

    def running?
      !!thread
    end

    def next_cycle
      initial_cycle! if @next_cycle == :initial
      @next_cycle
    end

    def reset
      self.next_cycle = :initial
      @task_history = nil
    end


    def to_h
      attrs = {
        name:       name,
        next_cycle: next_cycle.utc,
        type:       type,
        tag:        tag,
        task:       task,
        track_runs: track_runs,
      }
      case type
      when :interval
        attrs[:initial_delay] = ActiveSupport::Duration.build(delay) unless track_runs && last_run
        attrs[:interval] = ActiveSupport::Duration.build(interval)
      when :cron
        attrs[:cron] = cron.original
      end
      attrs.to_a.sort_by!{_1.to_s}.to_h
    end

    def inspect
      attrs = to_h.map{|k,v| "#{k}: #{v.inspect}"}
      %Q{#<#{self.class} #{attrs.join(', ')}>}
    end


    private

    attr_accessor :thread
    attr_writer :next_cycle, :track_runs

    # :cron            - cron definition
    # :interval        - interval period
    #   :initial_delay - delay of first run; nil = randomize; ignored if track_runs
    # :name            - task name
    # :tag             - logger tag; defaults to :name; false = no tag
    # :task            - proc/lambda to execute on each cycle
    # :track_runs      - whether to track last runs for catchup; defaults true except intervals < 15min
    def initialize(**args)
      @task = args[:task]
      @name = args[:name]
      @tag  = args.key?(:tag) ? args[:tag] : self.name
      if args[:interval]
        @type       = :interval
        @interval   = args[:interval]
        @delay      = args[:initial_delay] || rand(self.interval)
        @track_runs = args.key?(:track_runs) ? args[:track_runs] : self.interval >= 15.minutes
      else
        @type       = :cron
        @cron       = args[:cron]
        @track_runs = args.key?(:track_runs) ? args[:track_runs] : true
      end

      self.next_cycle = :initial
    end


    def initial_cycle!
      self.next_cycle =
        case type
        when :interval
          if last_run
            last_run + interval
          else
            Time.current + delay
          end
        when :cron
          prev_t = cron.previous_time.to_utc_time
          if last_run && last_run < prev_t
            prev_t
          else
            cron.next_time.to_utc_time
          end
        end
    end

    def next_cycle!
      self.next_cycle =
        case type
        when :interval
          Time.current + interval
        when :cron
          cron.next_time.to_utc_time
        end
    end

    def finish_before(grace: 0.1.seconds)
      case type
      when :interval
        Time.current + interval - grace
      when :cron
        cron.next_time.to_utc_time - grace
      end
    end
    public :finish_before


    def last_run
      track_runs && task_history.last_run_at
    rescue ActiveRecord::StatementInvalid => e
      if e.message =~ /relation "scheddy_task_histories" does not exist/
        logger.error <<~MSG
          [Scheddy] ERROR in task '#{name}': Missing DB table for Scheddy::TaskHistory.
            Either set  track_runs(false)  or run:
              bin/rails scheddy:install:migrations
              bin/rails db:migrate
            For now, disabling track_runs and continuing.
        MSG
        self.track_runs = false
      else
        raise
      end
    end

    def record_this_run
      return unless track_runs
      begin
        Scheddy::TaskHistory.connection.verify!
      rescue => e
        logger.error "Database offline while updating task history for Scheddy task '#{name}': #{e.inspect}"
        return
      end
      Scheddy::TaskHistory.logger.silence(Logger::INFO) do
        task_history.update last_run_at: Time.current
      end
    rescue ActiveRecord::ActiveRecordError => e
      logger.error "Error updating task history for Scheddy task '#{name}': #{e.inspect}"
    end

    def task_history
      @task_history ||= Scheddy::TaskHistory.find_or_create_by! name: name
    end

  end
end
