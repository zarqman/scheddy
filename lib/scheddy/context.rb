module Scheddy
  class Context

    def initialize(scheduler, finish_before)
      @scheduler = scheduler
      @finish_before = finish_before
    end

    delegate :stop?, to: :@scheduler
    attr_reader :finish_before

  end
end