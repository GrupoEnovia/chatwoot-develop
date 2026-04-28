class AiAgentPromptVersion < ApplicationRecord
  belongs_to :ai_agent
  belongs_to :created_by, class_name: 'User', optional: true

  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :prompt,  presence: true

  default_scope { order(version: :desc) }
end
