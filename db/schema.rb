# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20150120161319) do

  create_table "cloud_accounts", force: true do |t|
    t.string   "provider"
    t.string   "access_token"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "cloud_accounts", ["user_id", "provider"], name: "index_cloud_accounts_on_user_id_and_provider", unique: true
  add_index "cloud_accounts", ["user_id"], name: "index_cloud_accounts_on_user_id"

  create_table "csp_accounts", force: true do |t|
    t.string   "access_token"
    t.integer  "cloud_api_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "csp_accounts", ["cloud_api_id"], name: "index_csp_accounts_on_cloud_api_id"

  create_table "dropboxes", force: true do |t|
    t.string   "access_token"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
  end

  add_index "dropboxes", ["user_id"], name: "index_dropboxes_on_user_id"

  create_table "users", force: true do |t|
    t.string   "name"
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "password_digest"
    t.string   "remember_digest"
    t.boolean  "admin",             default: false
    t.string   "activation_digest"
    t.boolean  "activated",         default: false
    t.datetime "activated_at"
    t.string   "reset_digest"
    t.datetime "reset_sent_at"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true

end
