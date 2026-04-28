# == Schema Information
#
# Table name: kanban_tasks
#
#  id             :bigint           not null, primary key
#  completed_at   :datetime
#  description    :text
#  due_at         :datetime
#  due_date       :date
#  priority       :integer          default(1), not null
#  title          :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  assignee_id    :bigint
#  kanban_item_id :bigint           not null
#
# Indexes
#
#  index_kanban_tasks_on_assignee_id                      (assignee_id)
#  index_kanban_tasks_on_kanban_item_id                   (kanban_item_id)
#  index_kanban_tasks_on_kanban_item_id_and_completed_at  (kanban_item_id,completed_at)
#
class KanbanTask < ApplicationRecord
  PRIORITIES = { low: 0, medium: 1, high: 2 }.freeze
  RECURRENCE_FREQUENCIES = %w[daily weekly monthly].freeze

  belongs_to :kanban_item
  belongs_to :assignee, class_name: 'User', optional: true

  validates :title, presence: true, length: { maximum: 255 }
  validates :priority, inclusion: { in: PRIORITIES.values }
  validates :recurrence_frequency, inclusion: { in: RECURRENCE_FREQUENCIES }, allow_nil: true

  scope :pending, -> { where(completed_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }
  scope :overdue, -> { pending.where('due_at < ? OR due_date < ?', Time.current, Date.current) }
  scope :ordered, -> { order(Arel.sql("CASE WHEN completed_at IS NULL AND (due_at < NOW() OR due_date < CURRENT_DATE) THEN 0 ELSE 1 END, COALESCE(due_at, due_date::timestamp, created_at)")) }

  def completed?
    completed_at.present?
  end

  def overdue?
    return false if completed?

    (due_at.present? && due_at < Time.current) || (due_date.present? && due_date < Date.current)
  end

  def effective_due
    due_at || due_date&.to_time
  end
end
