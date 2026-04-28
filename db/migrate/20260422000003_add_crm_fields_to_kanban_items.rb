class AddCrmFieldsToKanbanItems < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_items, :contact_id, :bigint
    add_column :kanban_items, :lost_reason_id, :bigint
    add_index :kanban_items, :contact_id
    add_index :kanban_items, :lost_reason_id
  end
end
