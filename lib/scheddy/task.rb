module Scheddy
  class Task
    attr_reader :interval, :name, :task
    attr_accessor :next_cycle, :thread

    def initialize(duration, name: nil, offset: :random, &task)
      @interval = duration.to_i
      @name     = name || name_from_task(task)
      @offset   = offset
      @task     = task

      self.next_cycle = Time.current + self.offset
    end


    def perform(scheduler, now: false)
      return next_cycle if Time.current < next_cycle && !now
      if thread
        scheduler.logger.error "Scheddy task '#{name}' already running; skipping this cycle"
        return next_cycle!
      end
      self.thread =
        Thread.new do
          scheduler.logger.tagged name do
            Rails.application.reloader.wrap do
              task.call
            rescue Exception => e
              scheduler.logger.error "Exception in Scheddy task '#{name}': #{e.inspect}\n  #{e.backtrace.join("\n  ")}"
              Rails.error.report(e, handled: true)
            end
          end
          self.thread = nil
        end
      next_cycle!
    end


    def name_from_task(task)
      l = task.source_location.deep_dup
      l[0].sub!("#{Rails.root}/", '')
      l.join ':'
    end

    def next_cycle!
      self.next_cycle = Time.current + interval
    end

    def offset
      if @offset == :random
        rand interval
      else
        @offset.to_i
      end
    end

  end
end
