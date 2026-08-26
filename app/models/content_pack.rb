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

  def posters_complete?
    return true if generated_assets.empty?

    generated_assets.none?(&:in_progress?)
  end

  def posters_in_progress?
    generated_assets.any?(&:in_progress?)
  end

  def poster_states
    GeneratedAsset::TEMPLATE_KEYS.index_with do |key|
      asset = generated_assets.find { |row| row.template_key == key }
      next "missing" if asset.blank?
      next "ready" if asset.image.attached? || asset.status == "ready"
      asset.status
    end
  end
end
