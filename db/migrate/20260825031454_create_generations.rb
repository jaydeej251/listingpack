class CreateGenerations < ActiveRecord::Migration[8.0]
  def change
    create_table :generations do |t|
      t.references :content_pack, null: false, foreign_key: true
      t.string :kind
      t.string :prompt_version
      t.string :model
      t.integer :input_tokens
      t.integer :output_tokens
      t.text :error_message

      t.timestamps
    end
  end
end
