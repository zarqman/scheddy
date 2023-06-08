# Scheddy

Scheddy is a batteries-included task scheduler for Rails. It is intended as a replacement for cron and cron-like functionality (including job queue specific schedulers), with some useful differences.

* Flexible scheduling. Handles fixed times (Monday at 9am), intervals (every 15 minutes), and tiny intervals (every 5 seconds).
* Tiny intervals are great for scheduling workload specific jobs (database field `next_run_at`).
* Catch up missed tasks. Designed for environments with frequent deploys. Also useful in dev where the scheduler isn't always running.
* Job-queue agnostic. Works great with various ActiveJob adapters and non-ActiveJob queues too.
* Minimal dependencies. Uses your existing database; doesn't require Redis.
* Tasks and their schedules are versioned as part of your code.



## Installation
Add to your application's `Gemfile`:

```ruby
gem "scheddy"
```

After running `bundle install`, add the migration to your app:
```bash
bin/rails scheddy:install:migrations
bin/rails db:migrate
```

FYI, if all tasks set `track_runs false`, the migration can be skipped.



## Usage

Scheddy is configured with a straightforward DSL.

For clarity, Scheddy's units of work are referred to as Tasks. This is to differentiate them from background queue Jobs, like those run via ActiveJob. Scheddy's tasks have no relation to rake tasks.


Start by creating `config/initializers/scheddy.rb`:

```ruby
Scheddy.config do

  ## Fixed times
  task 'monday reports' do
    run_at '0 9 * * mon'  # cron syntax
    # run_at 'monday 9am' # use fugit's natural language parsing
    # track_runs false    # defaults to true for run_at() jobs
    perform do
      ReportJob.perform_later
    end
  end

  task 'tuesday reports' do
    run_when day: :tue, hour: 9..16, minute: [0,30]
      # a native ruby syntax is also supported
      #   :day    - day of week
      #   :month
      #   :date   - day of month
      #   :hour
      #   :minute
      #   :second
      # all values default to '*' (except second, which defaults to 0)
    # track_runs false    # defaults to true for run_when() jobs
    perform do
      AnotherReportJob.perform_later
    end
  end

  ## Intervals
  task 'send welcome emails' do
    run_every 30.minutes
    # track_runs false    # when run_every is >= 15.minutes, defaults to true; else to false
    perform do
      User.where(welcome_email_at: nil).find_each(batch_size: 100) do |user|
        WelcomeMailer.welcome_email.with(user: user).deliver_later
      end
    end
  end

  task 'heartbeat' do
    run_every 300  # seconds may be used instead
    perform 'HeartbeatJob.perform_later'  # a string to eval may be used too
  end

  # Use tiny intervals for lightweight scanning for ready-to-work records
  task 'disable expired accounts' do
    run_every 15.seconds
    logger_tag 'expired-scan'  # tag log lines with an alternate value; nil disables tagging
    perform do
      Subscription.expired.pluck(:id).each do |id|
        DisableAccountJob.perform_later id
      end
    end
  end

end
```


#### Fixed times: `run_at` and `run_when`

Fixed time tasks are comparable to cron-style scheduling. Times will be interpreted according to the Rails default TZ.

By default `run_at` and `run_when` will automatically catch up missed tasks. Scheddy does this by maintaining a record of the last run. If one or more runs was missed, it will run _once_ immediately. Multiple misses will still only be run once. Set `track_runs false` to disable catch-ups.


#### Intervals: `run_every`

Intervals are similar to cron style `*/5` syntax, but one key difference is the cycle is calculated based on Scheddy's startup time.

To avoid all tasks running at once, interval tasks are given an initial random delay of no more than the interval length itself. For example, a task running at 15 second intervals will be randomly delayed 0-14 seconds for first run. It will then continue running every 15 seconds.

By default, tiny interval tasks (those under 15 minutes) do not track last run or perform catch-ups, but longer interval tasks (>= 15 minutes) do. This is because tiny intervals will re-run soon anyway and it reduces database activity. Set `track_runs true|false` to override.



### Additional notes

#### Units of work

Notice that all these examples delegate the actual work to an external job. This is the recommended approach, but is not strictly required.

In general, bite-sized bits of work are fine in Scheddy, but bigger chunks of work usually belong in a background queue. In general, when timeliness is key (running right on time) or scheduling a background job is more costly than doing the work directly, then performing work inside the Scheddy task may be appropriate.

Database transactions are valid. These can increase use of database connections from the pool. Ensure Rails is configured appropriately.


#### Threading and execution

Each task runs in its own thread which helps ensure all tasks perform on time. However, Scheddy is not intended as a job executor and doesn't have a robust mechanism for retrying failed jobs--that belongs to your background job queue.

A given task will only ever be executed once at a time. Mostly relevant when using tiny intervals, if a prior execution is still going when the next execution is scheduled, Scheddy will skip the next execution and log an error message to that effect.


#### Task context

Tasks may receive an optional context to check if they need to stop for pending shutdown or to know the deadline for completing work before the next cycle would begin.

Deadlines (`finish_before`) are mostly useful if there is occasionally a large block of work combined with tiny intervals. The deadline is calculated with a near 2 second buffer. Only if that's inadequate do you need to adjust further. As already mentioned, Scheddy is smart enough to skip the next cycle if the prior cycle is still running, so handling deadlines is entirely optional.

```ruby
task 'iterating task' do
  run_every 15.seconds
  perform do |context|
    Model.where(...).find_each do |model|
      SomeJob.perform_later model.id if model.run_job?
      break if context.stop? # the scheduler has requested to shutdown
      break if context.finish_before < Time.now # the next cycle is imminent
    end
  end
end
```


#### Rails reloader

Each task's block is run inside the Rails reloader. In development mode, any classes referenced inside the block will be reloaded automatically to your latest code, just like the Rails dev-server itself.

It's possible to also make the task work reloadable by using a proxy class for the task itself. If your tasks are a bit bigger, organizing them into `app/tasks/` might be worthwhile anyway.

```ruby
# config/initializers/scheddy.rb
Scheddy.config do
  task 'weekly report' do
    run_at 'friday 9am'
    perform 'WeeklyReportTask.perform'
  end
end

# app/tasks/weekly_report_task.rb
class WeeklyReportTask
  def self.perform
    ReportJob.perform_later
  end
end
```



## Running Scheddy

Depending on your ruby setup, one of the following should do:
```bash
  scheddy start
  # OR
  bundle exec scheddy start
```

You can also check your tasks configuration with:
```bash
  scheddy tasks
  # OR
  bundle exec scheddy tasks
```


### In production

Scheddy runs as its own process. It is intended to be run only once. Because Scheddy has the ability to catch up missed tasks, redundancy should be achieved through automatic restarts via `systemd`, `dockerd`, Kubernetes, or whatever supervisory system you use.

During deployment, shutdown the old instance before starting the new one. In Kubernetes this might look like:
```yaml
kind: Deployment
spec:
  replicas: 1
  strategy:
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 1
  template:
    spec:
      terminationGracePeriodSeconds: 60
```


### In development (and `Procfile` in production)

Assuming you're using `Procfile.dev` or `Procfile` for development, add:
```bash
scheddy: bundle exec scheddy start
```


### Signals and shutdown

Scheddy will shutdown upon receiving an `INT`, `QUIT`, or `TERM` signal.

There is a default 45 second wait for tasks to complete, which should be more than enough for the tiny types of tasks at hand. Tasks may also check for when to stop work part way through. This may be useful in iterators processing large numbers of items. See Task Context above.


### Error handling

Scheddy's default error handler uses the Rails Errors API introduced in Rails 7. If your exception tracker of choice doesn't implement this API, or if using Rails 6.x, set your own error handler.

Note that the default handler is responsible for exception logging, so you must perform your own logging if wanted. If the handler is set to `nil`, exceptions will be silenced.

```ruby
Scheddy.config do
  error_handler do |exception, task|
    # displaying task.name is the most likely use of task
    name = "task '#{task.name}'" if task  # task might be nil
    logger.error "Exception in Scheddy #{name}: #{e.inspect}"
    # report the exception here
  end

  error_handler ->(exception){
    # passing a proc instead of a block is also allowed
    # the task arg can be left out if it won't be used
  }

  error_handler nil  # silence & don't report
end
```



## Compatibility
Used in production on Rails 7.0+. Gemspec is set to Rails 6.0+, but such is not well tested.


## Contributing
Pull requests are welcomed.


## License
MIT licensed.
