require 'thor'

module Scheddy
  class CLI < Thor

    class << self
      def exit_on_failure?
        true
      end
    end


    desc :start, "Run Scheddy's scheduler"
    def start
      load_app!
      Scheddy.run
    end


    desc :tasks, 'Show configured tasks'
    def tasks
      load_app!

      Scheddy.tasks.map do |t|
        OpenStruct.new t.to_h
      end.each do |t|
        puts <<~TASK.gsub(/$\s+$/m,'')
          #{t.type.to_s.humanize} task: #{t.name}
            #{"Interval:       #{t.interval&.inspect}" if t.interval}
            #{"Initial delay:  #{t.initial_delay&.inspect}" if t.initial_delay}
            #{"Cron rule:      #{t.cron}" if t.cron}
            Track runs?     #{t.track_runs}
            Next cycle:     #{t.next_cycle} (if run now)
            Tag:            #{t.tag.present? ? "[#{t.tag}]" : 'nil'}
        TASK
        puts ''
      end
    end


    no_commands do

      def load_app!
        require File.expand_path('config/environment.rb')
      end

    end
  end
end
