class AddChannelCopyToContentPacks < ActiveRecord::Migration[8.0]
  def change
    add_column :content_packs, :facebook_group_caption, :text
    add_column :content_packs, :marketplace_caption, :text
    add_column :content_packs, :messenger_followup, :text
    add_column :content_packs, :seller_report, :text
    add_column :content_packs, :stage, :string
  end
end
