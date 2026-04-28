# == Schema Information
#
# Table name: kanban_notes
#
#  id             :bigint           not null, primary key
#  content        :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  author_id      :bigint           not null
#  kanban_item_id :bigint           not null
#
# Indexes
#
#  index_kanban_notes_on_author_id       (author_id)
#  index_kanban_notes_on_kanban_item_id  (kanban_item_id)
#
class KanbanNote < ApplicationRecord
  belongs_to :kanban_item
  belongs_to :author, class_name: 'User'

  validates :content, presence: true

  scope :ordered, -> { order(created_at: :desc) }

  after_create :log_activity

  private

  def log_activity
    KanbanActivity.create!(
      kanban_item: kanban_item,
      author: author,
      action_type: 'note_added',
      metadata: { note_id: id, preview: content.truncate(100) }
    )
  end
end
