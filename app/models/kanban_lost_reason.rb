class KanbanLostReason < ApplicationRecord
  belongs_to :account

  validates :name, presence: true, length: { maximum: 255 }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
end
