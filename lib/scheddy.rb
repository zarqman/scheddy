require 'fugit'

%w(
  config
  context
  error_handler
  logger
  scheduler
  task
  version
  engine
).each do |f|
  require_relative "scheddy/#{f}"
end

module Scheddy

  def self.run
    Scheduler.new(tasks).run
  end

end
