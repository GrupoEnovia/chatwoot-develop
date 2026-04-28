# == Schema Information
#
# Table name: kanban_pipelines
#
#  id                  :bigint           not null, primary key
#  description         :text
#  is_active           :boolean          default(TRUE), not null
#  is_default          :boolean          default(FALSE), not null
#  name                :string           not null
#  position            :integer          default(0), not null
#  visibility_type     :string           default("all"), not null
#  visible_to_user_ids :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_kanban_pipelines_on_account_id               (account_id)
#  index_kanban_pipelines_on_account_id_and_position  (account_id,position)
#
class KanbanPipeline < ApplicationRecord
  belongs_to :account

  has_many :kanban_stages, -> { order(:position) }, foreign_key: :pipeline_id, dependent: :destroy
  has_many :kanban_items, foreign_key: :pipeline_id, dependent: :destroy
  has_many :kanban_automations, foreign_key: :pipeline_id, dependent: :destroy
  has_many :kanban_webhooks, foreign_key: :pipeline_id, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validates :visibility_type, inclusion: { in: %w[all specific] }

  scope :ordered, -> { order(:position, :created_at) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :active, -> { where(is_active: true) }
  scope :defaults, -> { where(is_default: true) }
end
