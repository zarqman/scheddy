require 'fugit'

module Scheddy
end

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
