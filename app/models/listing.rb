class Listing < ApplicationRecord
  LANGUAGES = {
    "taglish" => "Taglish",
    "english" => "English",
    "filipino" => "Filipino"
  }.freeze
  STATUSES = %w[draft generating ready failed].freeze
  STAGES = {
    "listed" => "Just listed",
    "price_reduced" => "Price reduced",
    "sold" => "Sold"
  }.freeze
  LISTING_TYPES = {
    "for_sale" => "For sale",
    "for_rent" => "For rent",
    "pre_selling" => "Pre-selling"
  }.freeze
  FINANCING_OPTIONS = {
    "pag_ibig" => "Pag-IBIG",
    "bank" => "Bank financing",
    "cash" => "Cash",
    "in_house" => "In-house",
    "negotiable" => "Negotiable"
  }.freeze

  belongs_to :user
  has_many :content_packs, dependent: :destroy
  has_many_attached :photos

  validates :title, :location, presence: true
  validates :language, inclusion: { in: LANGUAGES.keys }
  validates :status, inclusion: { in: STATUSES }
  validates :stage, inclusion: { in: STAGES.keys }
  validates :listing_type, inclusion: { in: LISTING_TYPES.keys }
  validates :financing, inclusion: { in: FINANCING_OPTIONS.keys }
  validate :photos_present, on: :create
  validate :previous_price_when_reduced

  def latest_pack
    content_packs.order(created_at: :desc).first
  end

  def peso_label
    format_price(price_amount)
  end

  def previous_peso_label
    format_price(previous_price_amount)
  end

  def facts_line
    [ bedrooms && "#{bedrooms}BR", bathrooms && "#{bathrooms.to_s.sub(/\.0$/, "")}BA", floor_area && "#{floor_area.to_i} sqm" ].compact.join(" · ")
  end

  def ph_badges
    badges = []
    badges << "Parking included" if parking?
    badges << "Assoc dues #{association_dues}" if association_dues.present?
    badges << FINANCING_OPTIONS[financing] unless financing == "negotiable"
    badges << LISTING_TYPES[listing_type] unless listing_type == "for_sale"
    badges << "Near #{near_transit}" if near_transit.present?
    badges
  end

  def stage_banner
    case stage
    when "price_reduced" then "PRICE REDUCED"
    when "sold" then "SOLD"
    else "JUST LISTED"
    end
  end

  def stage_label
    STAGES[stage]
  end

  def generating?
    status == "generating"
  end

  def ready?
    status == "ready"
  end

  def failed?
    status == "failed"
  end

  def pack_status
    return "generating" if generating?
    return "failed" if failed?
    return "ready" if ready?
    "draft"
  end

  def pack_status_label
    { "generating" => "Generating", "failed" => "Failed", "ready" => "Ready", "draft" => "Draft" }.fetch(pack_status)
  end

  private
    def photos_present
      errors.add(:photos, "add at least one listing photo") unless photos.attached?
    end

    def previous_price_when_reduced
      return unless stage == "price_reduced"
      return if previous_price_amount.present?

      errors.add(:previous_price_amount, "add the old price when the stage is price reduced")
    end

    def format_price(amount)
      return "Price on request" if amount.blank?

      "₱#{ActiveSupport::NumberHelper.number_to_delimited(amount.to_i)}"
    end
end
