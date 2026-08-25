class WeeklyCalendar < ApplicationRecord
  STATUSES = %w[pending generating ready failed].freeze

  belongs_to :user
  validates :week_start, presence: true
  validates :status, inclusion: { in: STATUSES }

  def ready?
    status == "ready"
  end

  def generating?
    status == "generating"
  end

  def failed?
    status == "failed"
  end

  def week_label
    ending = week_start + 4.days
    "#{week_start.strftime("%b %-d")}–#{ending.strftime("%-d")}"
  end

  def status_label
    { "ready" => "Ready", "generating" => "Generating", "failed" => "Failed", "pending" => "Draft" }.fetch(status, status.titleize)
  end
end
