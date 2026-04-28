class KanbanAutomationExecution < ApplicationRecord
  STATUSES = %w[pending running completed failed cancelled skipped].freeze

  belongs_to :kanban_item
  belongs_to :kanban_automation_action

  validates :status, inclusion: { in: STATUSES }

  scope :pending,   -> { where(status: 'pending') }
  scope :running,   -> { where(status: 'running') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed,    -> { where(status: 'failed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :for_item,  ->(item_id) { where(kanban_item_id: item_id) }

  def pending?   = status == 'pending'
  def running?   = status == 'running'
  def completed? = status == 'completed'
  def failed?    = status == 'failed'
  def cancelled? = status == 'cancelled'
end
