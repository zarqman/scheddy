module Scheddy
  class Task
    attr_reader :cron, :delay, :interval, :name, :task, :tag, :type
    attr_accessor :next_cycle, :thread

    delegate :logger, to: :Scheddy

    # :cron            - cron definition
    # :interval        - interval period
    #   :initial_delay - delay of first run
    # :name            - task name
    # :tag             - logger tag; defaults to :name; false = no tag
    # :task            - proc/lambda to execute on each cycle
    def initialize(**args)
      @task = args[:task]
      @name = args[:name]
              #|| name_from_task(task)
      @tag  = args.key?(:tag) ? args[:tag] : self.name
      if args[:interval]
        @type     = :interval
        @interval = args[:interval]
        @delay    = args[:initial_delay] || rand(self.interval)
      else
        @type = :cron
        @cron = args[:cron]
      end

      initial_cycle!
    end


    def perform(scheduler, now: false)
      return next_cycle if Time.current < next_cycle && !now
      if thread
        logger.error "Scheddy task '#{name}' already running; skipping this cycle"
        return next_cycle!
      end
      context = Context.new(scheduler, finish_before)
      self.thread =
        Thread.new do
          logger.tagged tag do
            Rails.application.reloader.wrap do
              task.call *[context].take(task.arity)
            rescue Exception => e
              logger.error "Exception in Scheddy task '#{name}': #{e.inspect}\n  #{e.backtrace.join("\n  ")}"
              Rails.error.report(e, handled: true, severity: :error)
            end
          end
          self.thread = nil
        end
      next_cycle!
    end


    def initial_cycle!
      self.next_cycle =
        case type
        when :interval
          Time.current + delay
        when :cron
          cron.next_time.to_utc_time
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

    def finish_before
      case type
      when :interval
        next_cycle + interval - 2.seconds
      when :cron
        cron.next_time.to_utc_time - 2.seconds
      end
    end

  end
end
