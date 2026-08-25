class BillingEvent < ApplicationRecord
  belongs_to :user, optional: true

  validates :event_id, :event_type, presence: true
  validates :event_id, uniqueness: true
end
