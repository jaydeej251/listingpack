class Generation < ApplicationRecord
  belongs_to :content_pack

  validates :kind, presence: true
end
