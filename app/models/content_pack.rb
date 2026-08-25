class ContentPack < ApplicationRecord
  STATUSES = %w[pending generating ready failed].freeze
  CAPTION_FIELDS = %w[
    listing_description
    facebook_caption
    facebook_group_caption
    marketplace_caption
    instagram_caption
    facebook_ad_copy
    messenger_followup
    seller_report
  ].freeze

  belongs_to :listing
  has_many :generated_assets, dependent: :destroy
  has_many :generations, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }

  def ready?
    status == "ready"
  end

  def generating?
    status == "generating"
  end
end
