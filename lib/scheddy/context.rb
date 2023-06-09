module Scheddy
  class Context

    def initialize(scheduler, task)
      @scheduler = scheduler
      @finish_before = task.finish_before
    end

    delegate :stop?, to: :@scheduler
    attr_reader :finish_before

  end
end