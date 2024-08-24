module Scheddy

  def self.run
    Scheduler.new(tasks).run
  end

  class Scheduler

    def run
      puts "[scheddy] Hello. This is Scheddy v#{VERSION}."
      puts "[scheddy] hostname=#{hostname}, pid=#{pid}, id=#{scheduler_id}"
      trap_signals!
      puts "[scheddy] Starting scheduler with #{tasks.size} #{'task'.pluralize tasks.size}"
      cleanup_task_history

      until stop?
        next_cycle = run_once
        wait_until next_cycle unless stop?
      end

      running = tasks.select(&:running?).count
      if running > 0
        puts "[scheddy] Waiting for #{running} tasks to complete"
        wait_until(45.seconds.from_now, skip_stop: true) do
          tasks.none?(&:running?)
        end
        tasks.select(&:running?).each do |task|
          $stderr.puts "[scheddy] Killing task #{task.name}"
          task.kill
        end
      end

      puts '[scheddy] Goodbye'
    end

    # return : Time of next cycle
    def run_once
      if tasks.empty?
        logger.warn 'No tasks found; doing nothing'
        return 1.hour.from_now
      end
      tasks.filter_map do |task|
        task.perform(self) unless stop?
      end.min
    end

    def stop? ; @stop ; end

    def hostname
      @hostname ||= Socket.gethostname.force_encoding(Encoding::UTF_8)
    end

    def pid
      @pid ||= Process.pid
    end

    def scheduler_id
      @scheduler_id ||= SecureRandom.alphanumeric 12
    end

    def logger
      @logger ||= Scheddy.logger.tagged "scheddy-#{scheduler_id}"
    end


    private

    attr_reader :tasks
    attr_writer :stop

    def initialize(tasks)
      @tasks = tasks
    end

    def cleanup_task_history
      known_tasks = tasks.select(&:track_runs).map(&:name)
      return if known_tasks.empty?  # table doesn't have to exist if track_runs always disabled
      Scheddy::TaskHistory.find_each do |r|
        r.destroy if known_tasks.exclude? r.name
      end
    rescue ActiveRecord::StatementInvalid => e
      return if e.message =~ /relation "scheddy_task_histories" does not exist/
      raise
    end

    def stop!(sig=nil)
      puts '[scheddy] Stopping'
      self.stop = true
    end

    def trap_signals!
      trap 'INT',  &method(:stop!)
      trap 'QUIT', &method(:stop!)
      trap 'TERM', &method(:stop!)
    end

    # &block - optional block - return truthy to end prematurely
    def wait_until(time, skip_stop: false)
      while (now = Time.current) < time
        return if stop? && !skip_stop
        return if block_given? && yield
        sleep [time-now, 1].min
      end
    end

  end
end
