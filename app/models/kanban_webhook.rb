# == Schema Information
#
# Table name: kanban_webhooks
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  events      :jsonb            not null
#  url         :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  pipeline_id :bigint
#
# Indexes
#
#  index_kanban_webhooks_on_account_id             (account_id)
#  index_kanban_webhooks_on_account_id_and_active  (account_id,active)
#  index_kanban_webhooks_on_pipeline_id            (pipeline_id)
#
class KanbanWebhook < ApplicationRecord
  VALID_EVENTS = %w[
    kanban.item.created
    kanban.item.updated
    kanban.item.deleted
    kanban.item.stage_changed
    kanban.item.won
    kanban.item.lost
  ].freeze

  belongs_to :account
  belongs_to :pipeline, class_name: 'KanbanPipeline', optional: true

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: 'must be a valid URL' }
  validates :events, presence: true
  validate :events_are_valid

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :global, -> { where(pipeline_id: nil) }
  scope :subscribed_to, ->(event) { where("events @> ?", [event].to_json) }

  private

  def events_are_valid
    return unless events.is_a?(Array)

    invalid = events - VALID_EVENTS
    errors.add(:events, "contains invalid events: #{invalid.join(', ')}") if invalid.any?
  end
end
