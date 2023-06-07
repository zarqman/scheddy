class CreateScheddyTaskHistories < ActiveRecord::Migration[6.0]
  def change
    # feel free to modify to  id: :uuid  or another :id format if you prefer
    create_table :scheddy_task_histories do |t|
      t.string     :name,        null: false, index: {unique: true}
      t.datetime   :last_run_at
      t.timestamps
    end
  end
end
