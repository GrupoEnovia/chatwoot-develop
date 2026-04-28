# == Schema Information
#
# Table name: kanban_activities
#
#  id             :bigint           not null, primary key
#  action_type    :string           not null
#  metadata       :jsonb            not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  author_id      :bigint
#  kanban_item_id :bigint           not null
#
# Indexes
#
#  index_kanban_activities_on_author_id                      (author_id)
#  index_kanban_activities_on_kanban_item_id                 (kanban_item_id)
#  index_kanban_activities_on_kanban_item_id_and_created_at  (kanban_item_id,created_at)
#
class KanbanActivity < ApplicationRecord
  ACTION_TYPES = %w[
    created moved assigned value_changed note_added
    task_created task_completed file_attached won lost reopened
    temperature_changed score_changed source_changed probability_changed
    conversation_linked phone_changed contact_linked
    automation_scheduled automation_cancelled automation_executed
    automation_message_sent automation_webhook_dispatched
    automation_task_created automation_failed automation_skipped
  ].freeze

  belongs_to :kanban_item
  belongs_to :author, class_name: 'User', optional: true

  validates :action_type, inclusion: { in: ACTION_TYPES }

  scope :ordered, -> { order(created_at: :desc) }
  scope :for_item, ->(item_id) { where(kanban_item_id: item_id) }
end
