class CreateGeneratedAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :generated_assets do |t|
      t.references :content_pack, null: false, foreign_key: true
      t.string :template_key, null: false

      t.timestamps
    end
  end
end
