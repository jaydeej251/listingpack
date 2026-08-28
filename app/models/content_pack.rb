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

  def active_poster_assets
    keys = GeneratedAsset.display_keys
    generated_assets.select { |asset| keys.include?(asset.template_key) }
  end

  def posters_complete?
    assets = active_poster_assets
    return true if assets.empty?

    assets.none?(&:in_progress?)
  end

  def posters_in_progress?
    active_poster_assets.any?(&:in_progress?)
  end

  def poster_states
    GeneratedAsset.display_keys.index_with do |key|
      asset = generated_assets.find { |row| row.template_key == key }
      next "missing" if asset.blank?
      next "ready" if asset.image.attached? || asset.status == "ready"
      asset.status
    end
  end
end
