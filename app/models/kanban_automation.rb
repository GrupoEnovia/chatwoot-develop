# == Schema Information
#
# Table name: kanban_automations
#
#  id                     :bigint           not null, primary key
#  active                 :boolean          default(TRUE), not null
#  conditions             :jsonb            not null
#  description            :text
#  name                   :string           not null
#  stop_on_human_takeover :boolean          default(FALSE), not null
#  stop_on_reply          :boolean          default(FALSE), not null
#  stop_on_stage_change   :boolean          default(TRUE), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  action_stage_id        :bigint
#  pipeline_id            :bigint           not null
#  trigger_stage_id       :bigint           not null
#
# Indexes
#
#  index_kanban_automations_on_action_stage_id         (action_stage_id)
#  index_kanban_automations_on_pipeline_id             (pipeline_id)
#  index_kanban_automations_on_pipeline_id_and_active  (pipeline_id,active)
#  index_kanban_automations_on_trigger_stage_id        (trigger_stage_id)
#
class KanbanAutomation < ApplicationRecord
  belongs_to :pipeline, class_name: 'KanbanPipeline'
  belongs_to :trigger_stage, class_name: 'KanbanStage'
  belongs_to :action_stage, class_name: 'KanbanStage', optional: true
  has_many   :kanban_automation_actions, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validate :trigger_and_action_stages_belong_to_pipeline

  scope :active,       -> { where(active: true) }
  scope :inactive,     -> { where(active: false) }
  scope :for_pipeline, ->(pipeline_id) { where(pipeline_id: pipeline_id) }
  scope :triggered_by, ->(stage_id) { where(trigger_stage_id: stage_id) }

  delegate :account_id, to: :pipeline

  private

  def trigger_and_action_stages_belong_to_pipeline
    if trigger_stage_id.present? && trigger_stage&.pipeline_id != pipeline_id
      errors.add(:trigger_stage, 'does not belong to the selected pipeline')
    end

    if action_stage_id.present? && action_stage&.pipeline_id != pipeline_id
      errors.add(:action_stage, 'does not belong to the selected pipeline')
    end
  end
end
