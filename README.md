# Scheddy

Scheddy is a batteries-included task scheduler for Rails. It is intended as a replacement for cron and cron-like functionality (including job queue specific schedulers), with some useful differences.

* Flexible scheduling. Handles intervals (every 15 minutes), tiny intervals (every 5 seconds), and context-specific times (database field `next_run_at`).
* Job-queue agnostic. Works great with various ActiveJob adapters and non-ActiveJob queues too.
* Tasks are versioned as part of your code.



## Installation
Add to your application's Gemfile:

```ruby
gem "scheddy"
```



## Usage

Scheddy is configured with a straightforward DSL.

For clarity, Scheddy's units of work are referred to as Tasks. This is to differentiate them from background queue Jobs, like those run via ActiveJob. Scheddy's tasks have no relation to rake tasks.


Start by creating `config/initializers/scheddy.rb`:

```ruby
Scheddy.config do

  ## Intervals
  run_every 5.minutes do
    HeartbeatJob.perform_later
  end

  run_every 30.minutes do
    User.where(welcome_email_at: nil).find_each(batch_size: 100) do |user|
      WelcomeMailer.welcome_email.with(user: user).deliver_later
    end
  end

  ## Data-context specific
  #  Use tiny intervals to scan for relevant work
  run_every 15.seconds do
    Subscription.expired.pluck(:id).each do |id|
      DisableAccountJob.perform_later id
    end
  end

end
```


#### Intervals

Intervals are similar to cron style `*/5` syntax, but one key difference is the cycle is calculated based on Scheddy's startup time.

To avoid all tasks running at once, interval tasks are given an initial random delay of no more than the interval length itself. For example, a task running at 15 second intervals will be randomly delayed 0-14 seconds for first run. It will then continue running every 15 seconds.



#### Additional notes

##### Units of work

Notice that all these examples delegate the actual work to an external job. This is the recommended approach, but is not strictly required.

In general, bite-sized bits of work are fine in Scheddy, but bigger chunks of work usually belong in a background queue. However, when timeliness is key or scheduling a background job is more costly than performing the work in Scheddy, then performing work in a Scheddy task may be appropriate.

Database transactions are valid. These can increase use of database connections from the pool. Ensure Rails is configured appropriately.


##### Threading and execution

Each task runs in its own thread which helps ensure all tasks perform on time. However, Scheddy is not intended as a job executor and doesn't have a robust mechanism for retrying failed jobs--that belongs to your background job queue.

A given task will only ever be executed once at a time. Mostly relevant when using tiny intervals, if a prior execution is still going when the next execution is scheduled, Scheddy will skip the next execution and log an error message to that effect.


#### Rails reloader

Each task's block is run inside the Rails reloader. In development mode, any classes referenced inside the block will be reloaded automatically to your latest code, just like the Rails dev-server itself.



## Running Scheddy

Scheddy is runnable as a rails/rake task. Depending on your ruby setup, one of the following should do:
```bash
  bundle exec rails scheddy:run
  bin/rails scheddy:run
  rails scheddy:run
```


### In production

Scheddy runs as its own process. It is intended to be run only once. Redundancy should be achieved through automatic restarts via `systemd`, `dockerd`, Kubernetes, or whatever supervisory system you use.

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
scheddy: bundle exec rails scheddy:run
```


### Signals and shutdown

Scheddy will shutdown upon receiving an `INT`, `QUIT`, or `TERM` signal.

There is a default 45 second wait for tasks to complete, which should be more than enough for the tiny types of tasks at hand.



## Compatibility
Used in production on Rails 7.0+. Gemspec is set to Rails 6.0+, but such is untested.


## Contributing
Pull requests are welcomed.


## License
MIT licensed.
