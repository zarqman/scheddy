class CreateScheddyTaskHistories < ActiveRecord::Migration[7.0]
  def change
    create_table :scheddy_task_histories do |t|
      t.string     :name,        null: false, index: {unique: true}
      t.datetime   :last_run_at
      t.timestamps
    end
  end
end
