class CreateBillingEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :billing_events do |t|
      t.string :provider, null: false, default: "paymongo"
      t.string :event_id, null: false
      t.string :event_type, null: false
      t.bigint :user_id
      t.jsonb :payload, null: false, default: {}
      t.datetime :processed_at
      t.timestamps
    end

    add_index :billing_events, :event_id, unique: true
    add_index :billing_events, :user_id
    add_foreign_key :billing_events, :users
  end
end
