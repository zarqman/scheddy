module Scheddy
end

%w(
  config
  engine
  scheduler
  task
  version
).each do |f|
  require_relative "scheddy/#{f}"
end
