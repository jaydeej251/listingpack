class GeneratedAsset < ApplicationRecord
  # key => pixel size for poster compositor + display metadata
  FORMATS = {
    "just_listed" => { width: 1080, height: 1080, label: "Square · Just listed", short: "Square" },
    "price_card" => { width: 1080, height: 1080, label: "Square · Price card", short: "Price" },
    "agent_card" => { width: 1080, height: 1080, label: "Square · Agent card", short: "Agent" },
    "story" => { width: 1080, height: 1920, label: "Story · 9:16", short: "Story" },
    "landscape" => { width: 1920, height: 1080, label: "Landscape · 16:9", short: "16:9" },
    "fb_banner" => { width: 1200, height: 628, label: "Facebook banner", short: "Banner" }
  }.freeze

  TEMPLATE_KEYS = FORMATS.keys.freeze
  FREE_POSTER_KEYS = %w[just_listed].freeze
  DEMO_TEMPLATE_KEYS = FREE_POSTER_KEYS
  CORE_TEMPLATE_KEYS = %w[just_listed price_card agent_card].freeze
  EXTENDED_TEMPLATE_KEYS = %w[fb_banner story landscape].freeze

  STATUSES = %w[pending rendering ready failed].freeze

  belongs_to :content_pack
  has_one_attached :image

  validates :template_key, inclusion: { in: TEMPLATE_KEYS }
  validates :status, inclusion: { in: STATUSES }

  def label
    FORMATS.fetch(template_key).fetch(:label)
  end

  def width
    FORMATS.fetch(template_key).fetch(:width)
  end

  def height
    FORMATS.fetch(template_key).fetch(:height)
  end

  def aspect_ratio_css
    self.class.aspect_ratio_css(template_key)
  end

  def pending? = status == "pending"
  def rendering? = status == "rendering"
  def ready? = status == "ready" || image.attached?
  def failed? = status == "failed"
  def in_progress? = pending? || rendering?

  def self.format_for(key)
    FORMATS.fetch(key.to_s)
  end

  def self.aspect_ratio_css(key)
    spec = format_for(key)
    "#{spec[:width]} / #{spec[:height]}"
  end

  def self.window_size(key)
    spec = format_for(key)
    [ spec[:width], spec[:height] ]
  end

  def self.generation_keys(user: nil)
    return keys_from_env if env_override_present?

    user&.pro? ? TEMPLATE_KEYS : FREE_POSTER_KEYS
  end

  def self.display_keys(user: nil)
    generation_keys(user: user)
  end

  def self.multi_format?(user: nil)
    display_keys(user: user).size > 1
  end

  def self.render_mode(user: nil)
    mode = ENV.fetch("POSTER_RENDER_MODE", "sequential").downcase
    mode
  end

  def self.batches(user: nil)
    keys = generation_keys(user: user)
    case render_mode(user: user)
    when "batch"
      keys.each_slice(3).to_a
    else
      keys.map { |key| [ key ] }
    end
  end

  def self.env_override_present?
    ENV["POSTER_FORMAT_SET"].present?
  end

  def self.keys_from_env
    case ENV.fetch("POSTER_FORMAT_SET").downcase
    when "demo", "single"
      key = ENV.fetch("POSTER_SINGLE_FORMAT", DEMO_TEMPLATE_KEYS.first)
      TEMPLATE_KEYS.include?(key) ? [ key ] : DEMO_TEMPLATE_KEYS
    when "core", "square", "free"
      CORE_TEMPLATE_KEYS
    else
      TEMPLATE_KEYS
    end
  end
  private_class_method :keys_from_env
end
