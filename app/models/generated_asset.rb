class GeneratedAsset < ApplicationRecord
  # key => pixel size for Ferrum + display metadata
  FORMATS = {
    "just_listed" => { width: 1080, height: 1080, label: "Square · Just listed", short: "Square" },
    "price_card" => { width: 1080, height: 1080, label: "Square · Price card", short: "Price" },
    "agent_card" => { width: 1080, height: 1080, label: "Square · Agent card", short: "Agent" },
    "story" => { width: 1080, height: 1920, label: "Story · 9:16", short: "Story" },
    "landscape" => { width: 1920, height: 1080, label: "Landscape · 16:9", short: "16:9" },
    "fb_banner" => { width: 1200, height: 628, label: "Facebook banner", short: "Banner" }
  }.freeze

  TEMPLATE_KEYS = FORMATS.keys.freeze
  # Original Free-friendly set — fits Render Free 512MB better than all six.
  CORE_TEMPLATE_KEYS = %w[just_listed price_card agent_card].freeze

  belongs_to :content_pack
  has_one_attached :image

  validates :template_key, inclusion: { in: TEMPLATE_KEYS }

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

  # POSTER_FORMAT_SET=core → three squares (pre-multi-format). Default/all → six formats.
  def self.generation_keys
    case ENV.fetch("POSTER_FORMAT_SET", "all").downcase
    when "core", "square", "free"
      CORE_TEMPLATE_KEYS
    else
      TEMPLATE_KEYS
    end
  end
end
