class CreateKanbanTasks < ActiveRecord::Migration[7.0]
  def change
    create_table :kanban_tasks do |t|
      t.bigint :kanban_item_id, null: false
      t.bigint :assignee_id
      t.string :title, null: false
      t.integer :priority, null: false, default: 1  # 0=low, 1=medium, 2=high
      t.date :due_date
      t.datetime :completed_at

      t.timestamps
    end

    add_index :kanban_tasks, :kanban_item_id
    add_index :kanban_tasks, :assignee_id
    add_index :kanban_tasks, [:kanban_item_id, :completed_at]
  end
end
