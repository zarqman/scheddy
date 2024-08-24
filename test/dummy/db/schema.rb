# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2024_08_22_165904) do
  create_table "scheddy_task_histories", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "last_run_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_scheddy_task_histories_on_name", unique: true
  end

  create_table "scheddy_task_schedulers", id: :string, force: :cascade do |t|
    t.string "hostname", null: false
    t.datetime "last_seen_at", precision: nil, null: false
    t.datetime "leader_expires_at", precision: nil
    t.string "leader_state"
    t.integer "lock_version", default: 0, null: false
    t.integer "pid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["leader_state"], name: "index_scheddy_task_schedulers_on_leader_state", unique: true
  end
end
