class AiAgentExecution < ApplicationRecord
  STATUSES    = %w[success error skipped buffered protocol].freeze
  INPUT_TYPES = %w[text audio image pdf].freeze

  belongs_to :ai_agent
  belongs_to :conversation

  validates :status,     inclusion: { in: STATUSES }
  validates :input_type, inclusion: { in: INPUT_TYPES }

  scope :successful, -> { where(status: 'success') }
  scope :recent,     -> { order(created_at: :desc) }
end
