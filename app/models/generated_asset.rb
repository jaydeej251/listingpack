class GeneratedAsset < ApplicationRecord
  TEMPLATE_KEYS = %w[just_listed price_card agent_card].freeze

  belongs_to :content_pack
  has_one_attached :image

  validates :template_key, inclusion: { in: TEMPLATE_KEYS }

  def label
    template_key.tr("_", " ").titleize
  end
end
