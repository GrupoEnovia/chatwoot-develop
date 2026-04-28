# == Schema Information
#
# Table name: kanban_items
#
#  id                  :bigint           not null, primary key
#  contact_phone       :string
#  expected_close_date :date
#  lost_at             :datetime
#  position            :integer          default(0), not null
#  probability         :integer          default(0)
#  score               :integer          default(0)
#  source              :string
#  tags                :jsonb            not null
#  temperature         :string
#  title               :string           not null
#  value               :decimal(15, 2)   default(0.0)
#  won_at              :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  assignee_id         :bigint
#  conversation_id     :bigint
#  pipeline_id         :bigint           not null
#  stage_id            :bigint           not null
#
# Indexes
#
#  index_kanban_items_on_account_id                  (account_id)
#  index_kanban_items_on_account_id_and_pipeline_id  (account_id,pipeline_id)
#  index_kanban_items_on_assignee_id                 (assignee_id)
#  index_kanban_items_on_conversation_id             (conversation_id)
#  index_kanban_items_on_pipeline_id                 (pipeline_id)
#  index_kanban_items_on_source                      (source)
#  index_kanban_items_on_stage_id                    (stage_id)
#  index_kanban_items_on_stage_id_and_position       (stage_id,position)
#  index_kanban_items_on_temperature                 (temperature)
#
class KanbanItem < ApplicationRecord
  SOURCES = %w[whatsapp instagram facebook google_ads ai_prospecting referral whatsapp_prospecting other].freeze
  TEMPERATURES = %w[hot warm cold].freeze

  belongs_to :account
  belongs_to :pipeline, class_name: 'KanbanPipeline'
  belongs_to :stage, class_name: 'KanbanStage'
  belongs_to :conversation, optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :contact, class_name: 'Contact', optional: true
  belongs_to :lost_reason, class_name: 'KanbanLostReason', optional: true

  has_many :kanban_tasks, dependent: :destroy
  has_many :kanban_notes, dependent: :destroy
  has_many :kanban_activities, dependent: :destroy
  has_many :kanban_attachments, dependent: :destroy

  validates :title, presence: true, length: { maximum: 255 }
  validates :value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validates :probability, numericality: { in: 0..100 }, allow_nil: true
  validates :score, numericality: { in: 0..5 }, allow_nil: true
  validates :source, inclusion: { in: SOURCES }, allow_nil: true
  validates :temperature, inclusion: { in: TEMPERATURES }, allow_nil: true
  validate :stage_belongs_to_pipeline

  scope :ordered, -> { order(:position, :created_at) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_pipeline, ->(pipeline_id) { where(pipeline_id: pipeline_id) }
  scope :for_stage, ->(stage_id) { where(stage_id: stage_id) }
  scope :assigned_to, ->(user_id) { where(assignee_id: user_id) }
  scope :with_source, ->(source) { where(source: source) }
  scope :with_temperature, ->(temp) { where(temperature: temp) }
  scope :won, -> { where.not(won_at: nil) }
  scope :lost, -> { where.not(lost_at: nil) }
  scope :open, -> { where(won_at: nil, lost_at: nil) }

  after_create :log_created_activity

  def won?
    won_at.present?
  end

  def lost?
    lost_at.present?
  end

  def open?
    won_at.nil? && lost_at.nil?
  end

  def status
    return 'won' if won?
    return 'lost' if lost?
    'open'
  end

  private

  def stage_belongs_to_pipeline
    return unless stage_id.present? && pipeline_id.present?

    errors.add(:stage, 'does not belong to the selected pipeline') unless stage&.pipeline_id == pipeline_id
  end

  def log_created_activity
    kanban_activities.create!(
      author: assignee,
      action_type: 'created',
      metadata: { title: title }
    )
  end
end
