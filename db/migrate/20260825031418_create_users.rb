class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :plan, null: false, default: "free"
      t.date :quota_period_start
      t.integer :packs_count_in_period, null: false, default: 0
      t.string :paymongo_customer_id

      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
