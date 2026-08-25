class User < ApplicationRecord
  FREE_PACKS_PER_MONTH = 3
  PLANS = %w[free pro].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_one :brand_kit, dependent: :destroy
  has_many :listings, dependent: :destroy
  has_many :weekly_calendars, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :plan, inclusion: { in: PLANS }

  after_create :ensure_brand_kit

  def pro?
    plan == "pro"
  end

  def free?
    !pro?
  end

  def admin?
    admin
  end

  def reset_quota_if_needed!
    start = Time.zone.today.beginning_of_month
    return if quota_period_start == start

    update!(quota_period_start: start, packs_count_in_period: 0)
  end

  def remaining_packs
    return Float::INFINITY if pro?

    reset_quota_if_needed!
    [ FREE_PACKS_PER_MONTH - packs_count_in_period, 0 ].max
  end

  def can_generate_pack?
    pro? || remaining_packs.positive?
  end

  # Atomically consume one Free pack credit. Returns false if denied.
  def consume_pack_quota!
    return true if pro?

    with_lock do
      reset_quota_if_needed!
      return false if packs_count_in_period >= FREE_PACKS_PER_MONTH

      increment!(:packs_count_in_period)
      true
    end
  end

  # Refund one Free pack credit after a failed copy generation.
  def refund_pack_quota!
    return if pro?

    with_lock do
      reset_quota_if_needed!
      return if packs_count_in_period <= 0

      decrement!(:packs_count_in_period)
    end
  end

  private
    def ensure_brand_kit
      create_brand_kit! unless brand_kit
    end
end
