class AiAgentProtocol < ApplicationRecord
  PROTOCOL_TYPES = %w[human qualified meeting unqualified custom].freeze

  belongs_to :ai_agent

  validates :protocol_type, inclusion: { in: PROTOCOL_TYPES }
  validates :label,   presence: true
  validates :keyword, presence: true

  default_scope { order(position: :asc) }
end
