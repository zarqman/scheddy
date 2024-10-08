namespace :scheddy do

  desc 'Run Scheddy'
  task run: :environment do
    Scheddy.run
  end

  desc 'Ask current Scheddy leader to step down'
  task stepdown: :environment do
    puts 'Requesting step down...'
    Scheddy::TaskScheduler.leader.first&.request_stepdown
  end

  task :migrate do
    `bin/rails db:migrate SCOPE=scheddy`
  end

  task :rollback do
    `bin/rails db:migrate SCOPE=scheddy VERSION=0`
  end

end
