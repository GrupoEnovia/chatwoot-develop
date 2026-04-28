class KanbanAutomationAction < ApplicationRecord
  ACTION_TYPES = %w[send_whatsapp send_webhook create_task].freeze
  DELAY_TYPES  = %w[minutes hours days business_days].freeze

  belongs_to :kanban_automation
  has_many   :kanban_automation_executions, dependent: :destroy

  validates :action_type, inclusion: { in: ACTION_TYPES }
  validates :delay_type,  inclusion: { in: DELAY_TYPES }
  validates :delay_minutes, numericality: { greater_than_or_equal_to: 0 }
  validates :position,      numericality: { greater_than_or_equal_to: 0 }
  validate  :config_valid_for_type

  scope :active,   -> { where(active: true) }
  scope :ordered,  -> { order(:position) }

  delegate :account_id, to: :kanban_automation

  private

  def config_valid_for_type
    case action_type
    when 'send_whatsapp'
      errors.add(:config, 'message is required') if config['message'].blank? && !config['use_ai']
    when 'send_webhook'
      errors.add(:config, 'url is required') if config['url'].blank?
    when 'create_task'
      errors.add(:config, 'title is required') if config['title'].blank?
    end
  end
end
