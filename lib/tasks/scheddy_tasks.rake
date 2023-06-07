namespace :scheddy do

  desc 'Run Scheddy'
  task run: :environment do
    Scheddy.run
  end

  task :migrate do
    `bin/rails db:migrate SCOPE=scheddy`
  end

  task :rollback do
    `bin/rails db:migrate SCOPE=scheddy VERSION=0`
  end

end
