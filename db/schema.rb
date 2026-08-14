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

ActiveRecord::Schema[8.1].define(version: 2026_08_14_212702) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "daily_picks", force: :cascade do |t|
    t.text "blurb"
    t.datetime "created_at", null: false
    t.integer "painting_id", null: false
    t.date "scheduled_on", null: false
    t.datetime "updated_at", null: false
    t.index ["painting_id"], name: "index_daily_picks_on_painting_id", unique: true
    t.index ["scheduled_on"], name: "index_daily_picks_on_scheduled_on", unique: true
  end

  create_table "devices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_seen_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_devices_on_token_digest", unique: true
  end

  create_table "favorites", force: :cascade do |t|
    t.string "collector_digest"
    t.datetime "created_at", null: false
    t.integer "painting_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["collector_digest", "painting_id"], name: "index_favorites_on_collector_digest_and_painting_id", unique: true
    t.index ["painting_id"], name: "index_favorites_on_painting_id"
    t.index ["user_id", "painting_id"], name: "index_favorites_on_user_id_and_painting_id", unique: true, where: "user_id IS NOT NULL"
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "paintings", force: :cascade do |t|
    t.string "accession_number"
    t.string "artist"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "creditline"
    t.string "culture"
    t.string "dated"
    t.string "department"
    t.text "description"
    t.string "dimension"
    t.integer "feed_order"
    t.integer "image_height"
    t.string "image_license"
    t.string "image_url_800"
    t.string "image_url_full"
    t.integer "image_width"
    t.string "life_date"
    t.string "medium"
    t.string "source", null: false
    t.integer "source_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["feed_order"], name: "index_paintings_on_feed_order"
    t.index ["source", "source_id"], name: "index_paintings_on_source_and_source_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "daily_picks", "paintings"
  add_foreign_key "favorites", "paintings"
  add_foreign_key "favorites", "users"
end
