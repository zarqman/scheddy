module Scheddy

  def self.run
    Scheduler.new(tasks).run
  end

  class Scheduler

    def run
      puts "[Scheddy] Starting scheduler with #{tasks.size} #{'task'.pluralize tasks.size}"
      trap_signals!

      until stop?
        next_cycle = run_once
        wait_until next_cycle unless stop?
      end

      running = tasks.select(&:thread).count
      if running > 0
        puts "[Scheddy] Waiting for #{running} tasks to complete"
        wait_until(45.seconds.from_now) do
          tasks.none?(&:thread)
        end
        tasks.select(&:thread).each do |task|
          $stderr.puts "[Scheddy] Killing task #{task.name}"
          task.thread&.kill
        end
      end

      puts '[Scheddy] Done'
    end

    # returns Time of next cycle
    def run_once
      tasks.flat_map do |task|
        task.perform(self) unless stop?
      end.min
    end


    attr_reader :tasks
    def initialize(tasks)
      @tasks = tasks
    end

    attr_writer :stop
    def stop? ; @stop ; end

    def stop!(sig=nil)
      puts '[Scheddy] Stopping'
      self.stop = true
    end

    def trap_signals!
      trap 'INT', &method(:stop!)
      trap 'QUIT', &method(:stop!)
      trap 'TERM', &method(:stop!)
    end

    # &block - optional block - return truthy to end prematurely
    def wait_until(time)
      while (now = Time.current) < time
        return if stop?
        return if block_given? && yield
        sleep [time-now, 1].min
      end
    end

  end
end
