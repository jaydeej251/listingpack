class CreateContentPacks < ActiveRecord::Migration[8.0]
  def change
    create_table :content_packs do |t|
      t.references :listing, null: false, foreign_key: true
      t.string :language, null: false, default: "taglish"
      t.string :status, null: false, default: "pending"
      t.text :listing_description
      t.text :facebook_caption
      t.text :instagram_caption
      t.text :facebook_ad_copy
      t.text :error_message

      t.timestamps
    end
  end
end
