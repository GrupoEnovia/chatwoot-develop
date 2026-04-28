class CreateKanbanNotes < ActiveRecord::Migration[7.0]
  def change
    create_table :kanban_notes do |t|
      t.bigint :kanban_item_id, null: false
      t.bigint :author_id, null: false
      t.text :content, null: false

      t.timestamps
    end

    add_index :kanban_notes, :kanban_item_id
    add_index :kanban_notes, :author_id
  end
end
