module Scheddy
  # default task list for when running standalone
  mattr_accessor :tasks, default: []

  # called from within task's execution thread; must be multi-thread safe
  # task is allowed to be nil
  mattr_accessor :error_handler, default: lambda {|e, task|
    logger.error "Exception in Scheddy task '#{task&.name}': #{e.inspect}\n  #{e.backtrace.join("\n  ")}"
    Rails.error.report(e, handled: true, severity: :error)
  }

  def self.config(&block)
    Config.new(tasks, &block)
  end


  class Config
    attr_reader :tasks

    delegate :logger, to: :Scheddy

    def initialize(tasks, &block)
      @tasks = tasks
      instance_eval(&block)
    end

    def error_handler(block1=nil, &block2)
      Scheddy.error_handler = block1 || block2
    end

    def task(name, &block)
      tasks.push TaskDefinition.new(name, &block).to_task
    end

    # shortcut syntax
    def run_at(cron, name:, tag: nil, &task)
      task(name) do
        run_at     cron
        logger_tag tag unless tag.nil?
        perform    &task
      end
    end

    # shortcut syntax
    def run_every(interval, name:, delay: nil, tag: nil, &task)
      task(name) do
        run_every     interval
        initial_delay delay if delay
        logger_tag    tag unless tag.nil?
        perform       &task
      end
    end

  end


  class TaskDefinition
    delegate :logger, to: :Scheddy

    # block  - task to perform
    # string - task to perform as evalable code, eg: 'SomeJob.perform_later'
    def perform(string=nil, &block)
      raise ArgumentError, 'Must provide string or block to perform' unless string.is_a?(String) ^ block
      block ||= lambda { eval(string) }
      task[:task] = block
    end

    # cron - String("min hour dom mon dow"), eg "0 4 * * *"
    def run_at(cron)
      task[:cron] =
        Fugit.parse_cronish(cron) ||
        Fugit.parse_cronish("every #{cron}") ||
        raise(ArgumentError, "Unable to parse '#{cron}'")
    end

    # duration - Duration or Integer
    def run_every(duration)
      task[:interval] = duration.to_i
    end

    # day    - day of week as Symbol (:monday, :mon) or Integer (both 0 and 7 are sunday)
    # month  - month as Symbol (:january, :jan) or Integer 1-12
    # date   - day of month, 1-31
    # hour   - 0-23
    # minute - 0-59
    # second - 0-59
    def run_when(day: '*', month: '*', date: '*', hour: '*', minute: '*', second: '0')
      day   = day.to_s[0,3]   if day.to_s =~ /[a-z]/
      month = month.to_s[0,3] if month.to_s =~ /[a-z]/
      run_at [second, minute, hour, date, month, day].map{normalize_val _1}.join(' ')
    end

    # duration - Duration or Integer (nil = random delay)
    def initial_delay(duration)
      task[:initial_delay] = duration&.to_i
    end

    # tag - String or false/nil; defaults to :name
    def logger_tag(tag)
      task[:tag] = tag
    end


    # private api
    def to_task
      Task.new **as_args
    end

    private

    attr_accessor :task

    def initialize(name, &block)
      self.task = {name: name}
      instance_eval(&block)
    end

    def as_args
      raise ArgumentError, 'Must call run_at, run_every, or run_when' unless task[:cron] || task[:interval]
      task
    end

    def normalize_val(val)
      case val
      when Array
        val.join(',')
      when Range
        "#{val.min}-#{val.max}"
      else
        val
      end
    end

  end
end
