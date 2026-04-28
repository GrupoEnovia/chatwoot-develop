class CreateKanbanAutomationExecutions < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_automation_executions do |t|
      t.references :kanban_item,              null: false, foreign_key: true, index: true
      t.references :kanban_automation_action, null: false, foreign_key: true, index: true
      t.string     :status,       null: false, default: 'pending'
      t.datetime   :scheduled_at
      t.datetime   :executed_at
      t.text       :error_message
      t.jsonb      :result, null: false, default: {}
      t.timestamps
    end

    add_index :kanban_automation_executions, :status
    add_index :kanban_automation_executions, %i[kanban_item_id status]
    add_index :kanban_automation_executions, :scheduled_at
  end
end
