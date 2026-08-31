class AddShareTokenToListings < ActiveRecord::Migration[8.0]
  def up
    add_column :listings, :share_token, :string
    add_index :listings, :share_token, unique: true

    say_with_time "backfill listing share tokens" do
      Listing.reset_column_information
      Listing.unscoped.where(share_token: [ nil, "" ]).find_each do |listing|
        loop do
          token = SecureRandom.base58(16)
          unless Listing.unscoped.exists?(share_token: token)
            listing.update_columns(share_token: token)
            break
          end
        end
      end
    end

    change_column_null :listings, :share_token, false
  end

  def down
    remove_index :listings, :share_token
    remove_column :listings, :share_token
  end
end
