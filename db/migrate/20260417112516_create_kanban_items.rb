class CreateKanbanItems < ActiveRecord::Migration[7.0]
  def change
    create_table :kanban_items do |t|
      t.bigint :account_id, null: false
      t.bigint :pipeline_id, null: false
      t.bigint :stage_id, null: false
      t.bigint :conversation_id
      t.bigint :assignee_id
      t.string :contact_phone
      t.string :title, null: false
      t.decimal :value, precision: 15, scale: 2, default: 0
      t.integer :position, null: false, default: 0
      t.datetime :won_at
      t.datetime :lost_at

      t.timestamps
    end

    add_index :kanban_items, :account_id
    add_index :kanban_items, :pipeline_id
    add_index :kanban_items, :stage_id
    add_index :kanban_items, :conversation_id
    add_index :kanban_items, :assignee_id
    add_index :kanban_items, [:stage_id, :position]
    add_index :kanban_items, [:account_id, :pipeline_id]
  end
end
