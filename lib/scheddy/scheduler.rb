module Scheddy
  LEASE_RENEWAL_INTERVAL = 1.minute
  LEASE_DURATION         = 4.minutes
    # must be > 2x the renewal interval

  def self.run
    Scheduler.new(tasks).run
  end

  class Scheduler

    def run
      puts "[scheddy] Hello. This is Scheddy v#{VERSION}."
      puts "[scheddy] hostname=#{hostname}, pid=#{pid}, id=#{scheduler_id}"
      trap_signals!
      puts "[scheddy] Starting scheduler with #{tasks.size} #{'task'.pluralize tasks.size}"
      unless register_process
        puts '[scheddy] No scheddy_task_schedulers table found; disabling cluster support'
      end

      until stop?
        with_leader do |new_leader|
          reset_tasks if new_leader
          cleanup_task_history
          cleanup_task_scheduler

          next_cycle = run_once
          if tasks.any? && scheduler_record
            next_cycle = [next_cycle, LEASE_RENEWAL_INTERVAL.from_now].compact.min
          end
          wait_until next_cycle unless stop?
        end
      end

      stepdown_as_leader

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

    ensure
      unregister_process
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

    def stepdown? ; @stepdown ; end
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

    attr_reader :scheduler_record, :tasks
    attr_writer :stepdown, :stop
    attr_accessor :leader_state

    def initialize(tasks)
      @tasks = tasks
      self.leader_state = :standby
    end

    def cleanup_task_history
      return if @cleaned_tasks
      @cleaned_tasks = true
      known_tasks = tasks.select(&:track_runs).map(&:name)
      return if known_tasks.empty?  # table doesn't have to exist if track_runs always disabled
      Scheddy::TaskHistory.find_each do |r|
        r.destroy if known_tasks.exclude? r.name
      end
    rescue ActiveRecord::StatementInvalid => e
      return if e.message =~ /relation "scheddy_task_histories" does not exist/
      raise
    end

    def cleanup_task_scheduler
      return if @cleaned_schedulers
      @cleaned_schedulers = true
      return unless Scheddy::TaskScheduler.table_exists?
      Scheddy::TaskScheduler.stale.find_each do |r|
        logger.debug "Removing stale scheduler record for id=#{r.id}"
        r.destroy
      end
    end

    def register_process
      return false unless Scheddy::TaskScheduler.table_exists?
      @scheduler_record ||= Scheddy::TaskScheduler.create!(
        id:           scheduler_id,
        hostname:     hostname,
        last_seen_at: Time.current,
        pid:          pid
      )
    end

    def unregister_process
      Scheddy::TaskScheduler.delete scheduler_record.id if scheduler_record
    end

    def reset_tasks
      tasks.each(&:reset)
    end

    def stepdown!(sig=nil)
      if scheduler_record&.leader?
        puts '[scheddy] Requesting step down'
        self.stepdown = true
      end
    end

    def stop!(sig=nil)
      puts '[scheddy] Stopping'
      self.stop = true
    end

    def trap_signals!
      trap 'INT',  &method(:stop!)
      trap 'QUIT', &method(:stop!)
      trap 'TERM', &method(:stop!)
      trap 'USR1', &method(:stepdown!)
    end

    def wait_for(duration, skip_stop: false, &block)
      wait_until duration.from_now, skip_stop:, &block
    end

    # &block - optional block - return truthy to end prematurely
    def wait_until(time, skip_stop: false)
      while (now = Time.current) < time
        return if stop? && !skip_stop
        return if block_given? && yield
        sleep [time-now, 1].min
      end
    end

    def with_leader
      return yield(false) if !scheduler_record || tasks.empty?

      wait_t = LEASE_RENEWAL_INTERVAL.from_now
      if leader_state == :standby
        if current_leader = Scheddy::TaskScheduler.leader.first
          if current_leader.expired?
            logger.error "Forcefully clearing expired leader status for id=#{current_leader.id}"
            current_leader.clear_leader(only_if_expired: true)
            wait_t = 5.seconds.from_now
          end
        else
          if scheduler_record.take_leadership
            self.leader_state = :new_leader
          end
        end
      end

      case leader_state
      when :new_leader
        logger.info 'We are now cluster leader'
        self.leader_state = :existing_leader
        return yield true
      when :existing_leader
        if !stepdown? && scheduler_record.renew_leadership
          return yield false
        else
          if stepdown_as_leader
            scheduler_record.mark_seen
          end
          wait_t += 5.seconds # improve odds of another daemon taking over
        end
      when :standby
        scheduler_record.mark_seen
      end

      wait_until wait_t
    rescue Exception => e
      logger.error 'Error in scheduler; retrying in 1 minute'
      Scheddy.handle_error(e)
      if leader_state != :standby
        logger.warn 'Due to prior error, stepping down as leader'
        stepdown_as_leader skip_msg: true
      end
      wait_for 1.minute
    end

    def stepdown_as_leader(skip_msg: false)
      return true if leader_state == :standby
      logger.info 'Stepping down as leader' unless skip_msg
      scheduler_record.clear_leader
      self.stepdown = false
      self.leader_state = :standby
      true
    rescue Exception => e
      logger.error 'Failed to step down as leader'
      Scheddy.handle_error(e)
      false
    end

  end
end
