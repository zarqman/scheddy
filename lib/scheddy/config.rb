module Scheddy
  mattr_accessor :tasks, default: []

  def self.config(&block)
    Config.class_eval(&block)
  end


  class Config
    class << self
      delegate :tasks, :tasks=, to: :Scheddy

      # (duration, **options, &task)
      def run_every(...)
        self.tasks += [Task.new(...)]
      end

    end
  end

end
