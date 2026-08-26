class AddStatusToGeneratedAssets < ActiveRecord::Migration[8.0]
  def change
    add_column :generated_assets, :status, :string, null: false, default: "pending"
    add_column :generated_assets, :error_message, :text
  end
end
