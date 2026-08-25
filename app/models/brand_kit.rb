class BrandKit < ApplicationRecord
  belongs_to :user
  has_one_attached :logo
  has_one_attached :headshot

  validates :display_name, presence: true, on: :update
  validates :primary_color, format: { with: /\A#(?:[0-9a-fA-F]{3}){1,2}\z/, allow_blank: true }
  validates :secondary_color, format: { with: /\A#(?:[0-9a-fA-F]{3}){1,2}\z/, allow_blank: true }

  def name
    display_name.presence || user.email_address
  end

  def accent
    primary_color.presence || "#C45C26"
  end

  def ink
    secondary_color.presence || "#14213D"
  end
end
