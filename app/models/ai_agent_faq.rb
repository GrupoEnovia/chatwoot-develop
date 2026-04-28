class AiAgentFaq < ApplicationRecord
  CATEGORIES = %w[faq objection context].freeze

  belongs_to :ai_agent

  validates :category, inclusion: { in: CATEGORIES }
  validates :question, presence: true
  validates :answer,   presence: true

  scope :active,  -> { where(active: true) }
  scope :by_category, ->(cat) { where(category: cat) }
end
