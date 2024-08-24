class CreateScheddyTaskSchedulers < ActiveRecord::Migration[6.0]
  def change
    create_table :scheddy_task_schedulers, id: :string do |t|
      t.string     :hostname,          null: false
      t.datetime   :last_seen_at,      null: false
      t.datetime   :leader_expires_at
      t.string     :leader_state
      t.integer    :lock_version,      null: false, default: 0
      t.integer    :pid,               null: false
      t.timestamps

      t.index :leader_state, unique: true
    end
  end
end
