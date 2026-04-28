class AiAgent < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true

  has_many :ai_agent_prompt_versions, dependent: :destroy
  has_many :ai_agent_protocols,       dependent: :destroy
  has_many :ai_agent_faqs,            dependent: :destroy
  has_many :ai_agent_conversations,   dependent: :destroy
  has_many :ai_agent_executions,      dependent: :destroy
  has_one  :ai_agent_schedule,        dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validates :inbox_id, uniqueness: { scope: :account_id }, allow_nil: true
  validates :message_buffer_seconds, numericality: { greater_than_or_equal_to: 10 }

  scope :active,   -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  def publish_prompt!(new_prompt, user = nil)
    new_version = prompt_version + 1
    ai_agent_prompt_versions.create!(
      version:    new_version,
      prompt:     new_prompt,
      created_by: user
    )
    update!(prompt: new_prompt, prompt_version: new_version, prompt_draft: {})
  end

  def save_draft!(draft_prompt)
    update!(prompt_draft: draft_prompt)
  end

  def has_draft?
    prompt_draft.present? && prompt_draft.any?
  end
end
