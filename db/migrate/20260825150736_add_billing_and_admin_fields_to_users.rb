class AddBillingAndAdminFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :paymongo_checkout_session_id, :string
    add_column :users, :admin, :boolean, null: false, default: false
  end
end
