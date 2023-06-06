module Scheddy

  def self.run
    Scheduler.new.run
  end

  class Scheduler

    def run
      puts "[Scheddy] Starting scheduler with #{tasks.size} tasks"
      trap_signals!

      until stop?
        next_cycle =
          tasks.flat_map do |task|
            task.perform(self) unless stop?
          end.min
        wait_until next_cycle unless stop?
      end

      puts '[Scheddy] Waiting for tasks to complete'
      wait_until(45.seconds.from_now) do
        tasks.none?(&:thread)
      end
      tasks.select(&:thread).each do |task|
        $stderr.puts "[Scheddy] Killing task #{task.name}"
        task.thread&.kill
      end

      puts '[Scheddy] Done'
    end


    delegate :tasks, to: :Scheddy

    attr_writer :logger, :stop

    def logger
      @logger ||= Rails.logger
    end

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
