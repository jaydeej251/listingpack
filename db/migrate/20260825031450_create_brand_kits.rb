class CreateBrandKits < ActiveRecord::Migration[8.0]
  def change
    create_table :brand_kits do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :display_name
      t.string :phone
      t.string :facebook_name
      t.string :primary_color, default: "#C45C26"
      t.string :secondary_color, default: "#14213D"
      t.text :voice_samples

      t.timestamps
    end
  end
end
