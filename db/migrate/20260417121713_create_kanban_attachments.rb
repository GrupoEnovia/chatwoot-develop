class CreateKanbanAttachments < ActiveRecord::Migration[7.0]
  def change
    create_table :kanban_attachments do |t|
      t.bigint :kanban_item_id, null: false
      t.bigint :uploaded_by_id, null: false
      t.string :file_name, null: false
      t.integer :file_size
      t.string :file_type
      t.string :url, null: false

      t.timestamps
    end

    add_index :kanban_attachments, :kanban_item_id
    add_index :kanban_attachments, :uploaded_by_id
  end
end
