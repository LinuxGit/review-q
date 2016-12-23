# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20161223010732) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "channels", force: :cascade do |t|
    t.integer "team_id"
    t.string  "slack_id"
  end

  create_table "items", force: :cascade do |t|
    t.integer "channel_id"
    t.integer "user_id"
    t.string  "ts"
    t.string  "message"
    t.string  "archive_link"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name"
    t.string "slack_id"
    t.string "bot_slack_id"
    t.string "bot_token"
  end

  create_table "users", force: :cascade do |t|
    t.string  "first_name"
    t.string  "last_name"
    t.string  "slack_id"
    t.string  "token"
    t.integer "team_id"
    t.string  "avatar_24"
    t.string  "slack_username"
  end

end
