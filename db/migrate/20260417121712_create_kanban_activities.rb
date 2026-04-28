class CreateKanbanActivities < ActiveRecord::Migration[7.0]
  def change
    create_table :kanban_activities do |t|
      t.bigint :kanban_item_id, null: false
      t.bigint :author_id
      t.string :action_type, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :kanban_activities, :kanban_item_id
    add_index :kanban_activities, :author_id
    add_index :kanban_activities, [:kanban_item_id, :created_at]
  end
end
