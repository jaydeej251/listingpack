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

ActiveRecord::Schema[8.0].define(version: 2026_09_01_015200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "billing_events", force: :cascade do |t|
    t.string "provider", default: "paymongo", null: false
    t.string "event_id", null: false
    t.string "event_type", null: false
    t.bigint "user_id"
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_billing_events_on_event_id", unique: true
    t.index ["user_id"], name: "index_billing_events_on_user_id"
  end

  create_table "brand_kits", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "display_name"
    t.string "phone"
    t.string "facebook_name"
    t.string "primary_color", default: "#C45C26"
    t.string "secondary_color", default: "#14213D"
    t.text "voice_samples"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_brand_kits_on_user_id", unique: true
  end

  create_table "content_packs", force: :cascade do |t|
    t.bigint "listing_id", null: false
    t.string "language", default: "taglish", null: false
    t.string "status", default: "pending", null: false
    t.text "listing_description"
    t.text "facebook_caption"
    t.text "instagram_caption"
    t.text "facebook_ad_copy"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "facebook_group_caption"
    t.text "marketplace_caption"
    t.text "messenger_followup"
    t.text "seller_report"
    t.string "stage"
    t.index ["listing_id"], name: "index_content_packs_on_listing_id"
  end

  create_table "generated_assets", force: :cascade do |t|
    t.bigint "content_pack_id", null: false
    t.string "template_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "pending", null: false
    t.text "error_message"
    t.index ["content_pack_id"], name: "index_generated_assets_on_content_pack_id"
  end

  create_table "generations", force: :cascade do |t|
    t.bigint "content_pack_id", null: false
    t.string "kind"
    t.string "prompt_version"
    t.string "model"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_pack_id"], name: "index_generations_on_content_pack_id"
  end

  create_table "listings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.string "location"
    t.decimal "price_amount", precision: 12, scale: 2
    t.integer "bedrooms"
    t.decimal "bathrooms", precision: 3, scale: 1
    t.decimal "floor_area", precision: 8, scale: 2
    t.text "amenities"
    t.text "notes"
    t.string "language", default: "taglish", null: false
    t.string "status", default: "draft", null: false
    t.boolean "price_confirmed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stage", default: "listed", null: false
    t.string "listing_type", default: "for_sale", null: false
    t.string "financing", default: "negotiable", null: false
    t.decimal "previous_price_amount", precision: 12, scale: 2
    t.string "association_dues"
    t.string "near_transit"
    t.boolean "parking", default: false, null: false
    t.string "share_token", null: false
    t.index ["share_token"], name: "index_listings_on_share_token", unique: true
    t.index ["stage"], name: "index_listings_on_stage"
    t.index ["user_id", "created_at"], name: "index_listings_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_listings_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "plan", default: "free", null: false
    t.date "quota_period_start"
    t.integer "packs_count_in_period", default: 0, null: false
    t.string "paymongo_customer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "paymongo_checkout_session_id"
    t.boolean "admin", default: false, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "weekly_calendars", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "week_start", null: false
    t.string "focus_area"
    t.string "status", default: "pending", null: false
    t.jsonb "posts", default: [], null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "week_start"], name: "index_weekly_calendars_on_user_id_and_week_start"
    t.index ["user_id"], name: "index_weekly_calendars_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "billing_events", "users"
  add_foreign_key "brand_kits", "users"
  add_foreign_key "content_packs", "listings"
  add_foreign_key "generated_assets", "content_packs"
  add_foreign_key "generations", "content_packs"
  add_foreign_key "listings", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "weekly_calendars", "users"
end
