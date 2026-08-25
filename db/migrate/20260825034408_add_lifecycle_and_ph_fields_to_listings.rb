class AddLifecycleAndPhFieldsToListings < ActiveRecord::Migration[8.0]
  def change
    add_column :listings, :stage, :string, null: false, default: "listed"
    add_column :listings, :listing_type, :string, null: false, default: "for_sale"
    add_column :listings, :financing, :string, null: false, default: "negotiable"
    add_column :listings, :previous_price_amount, :decimal, precision: 12, scale: 2
    add_column :listings, :association_dues, :string
    add_column :listings, :near_transit, :string
    add_column :listings, :parking, :boolean, null: false, default: false
    add_index :listings, :stage
  end
end
