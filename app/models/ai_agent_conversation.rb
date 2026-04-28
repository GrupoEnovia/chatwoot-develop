class AiAgentConversation < ApplicationRecord
  STATES = %w[active paused transferred ended].freeze

  belongs_to :ai_agent
  belongs_to :conversation
  belongs_to :contact, optional: true

  validates :state, inclusion: { in: STATES }

  scope :active,      -> { where(state: 'active') }
  scope :paused,      -> { where(state: 'paused') }
  scope :transferred, -> { where(state: 'transferred') }

  def pause!(reason = nil)
    update!(state: 'paused', paused_reason: reason)
  end

  def resume!
    update!(state: 'active', paused_reason: nil)
  end

  def transfer!(reason: nil)
    update!(state: 'transferred', paused_reason: reason)
  end

  def end!
    update!(state: 'ended')
  end
end
