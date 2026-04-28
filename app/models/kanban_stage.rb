# == Schema Information
#
# Table name: kanban_stages
#
#  id          :bigint           not null, primary key
#  color       :string           default("#6366f1")
#  is_lost     :boolean          default(FALSE), not null
#  is_won      :boolean          default(FALSE), not null
#  name        :string           not null
#  position    :integer          default(0), not null
#  probability :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  pipeline_id :bigint           not null
#
# Indexes
#
#  index_kanban_stages_on_pipeline_id               (pipeline_id)
#  index_kanban_stages_on_pipeline_id_and_position  (pipeline_id,position)
#
class KanbanStage < ApplicationRecord
  belongs_to :pipeline, class_name: 'KanbanPipeline'

  has_many :kanban_items, foreign_key: :stage_id, dependent: :restrict_with_error
  has_many :trigger_automations, class_name: 'KanbanAutomation', foreign_key: :trigger_stage_id, dependent: :destroy
  has_many :action_automations, class_name: 'KanbanAutomation', foreign_key: :action_stage_id, dependent: :nullify

  validates :name, presence: true, length: { maximum: 255 }
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validates :color, format: { with: /\A#[0-9a-fA-F]{3,6}\z/, message: 'must be a valid hex color' }, allow_blank: true
  validates :probability, numericality: { in: 0..100 }

  validate :only_one_won_stage_per_pipeline
  validate :only_one_lost_stage_per_pipeline

  scope :ordered, -> { order(:position) }
  scope :for_pipeline, ->(pipeline_id) { where(pipeline_id: pipeline_id) }

  delegate :account_id, to: :pipeline

  private

  def only_one_won_stage_per_pipeline
    return unless is_won?

    existing = pipeline.kanban_stages.where(is_won: true)
    existing = existing.where.not(id: id) if persisted?
    errors.add(:is_won, 'já existe uma etapa marcada como Ganho neste pipeline') if existing.exists?
  end

  def only_one_lost_stage_per_pipeline
    return unless is_lost?

    existing = pipeline.kanban_stages.where(is_lost: true)
    existing = existing.where.not(id: id) if persisted?
    errors.add(:is_lost, 'já existe uma etapa marcada como Perdido neste pipeline') if existing.exists?
  end
end
