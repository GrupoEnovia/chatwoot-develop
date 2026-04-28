class AddStartDateAndRecurrenceToKanbanTasks < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_tasks, :start_date, :date
    add_column :kanban_tasks, :is_recurring, :boolean, default: false, null: false
    add_column :kanban_tasks, :recurrence_frequency, :string
    add_column :kanban_tasks, :recurrence_interval, :integer, default: 1
    add_column :kanban_tasks, :recurrence_end_date, :date
  end
end
