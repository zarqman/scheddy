namespace :scheddy do

  desc 'Run Scheddy'
  task run: :environment do
    Scheddy.run
  end

end
