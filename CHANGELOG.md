#### 0.4.3

- Tidy up migration syntax

#### 0.4.2 (broken)

#### 0.4.1

- Update migrations to 7.0
  This causes the datetime columns to honor non-default values for
  `ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type`.

#### 0.4.0

- Minimum Rails is now 7.x

#### 0.3.0

- Add native clustering support
- Rework logging
- Tidy up error handling

#### 0.2.2

- Recover from lost DB connections in main thread

#### 0.2.1

- Handle ActiveRecord not present

#### 0.2.0

- CLI: add 'scheddy version'; improve 'scheddy tasks'
- Scheduler: fix shutdown with active tasks
- Task: drop fixed 2s grace period in `finish_before`
- Task: improve error handling

#### 0.1.0

- Initial release
