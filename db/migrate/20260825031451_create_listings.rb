class CreateListings < ActiveRecord::Migration[8.0]
  def change
    create_table :listings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.string :location
      t.decimal :price_amount, precision: 12, scale: 2
      t.integer :bedrooms
      t.decimal :bathrooms, precision: 3, scale: 1
      t.decimal :floor_area, precision: 8, scale: 2
      t.text :amenities
      t.text :notes
      t.string :language, null: false, default: "taglish"
      t.string :status, null: false, default: "draft"
      t.boolean :price_confirmed, null: false, default: false

      t.timestamps
    end
    add_index :listings, [ :user_id, :created_at ]
  end
end
