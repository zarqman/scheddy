module Scheddy
  class << self

    attr_writer :logger

    def logger
      @logger ||= Rails.logger
    end

  end
end
