class AddLeadFieldsToKanbanItems < ActiveRecord::Migration[7.0]
  def change
    add_column :kanban_items, :source, :string
    add_column :kanban_items, :temperature, :string
    add_column :kanban_items, :probability, :integer, default: 0
    add_column :kanban_items, :expected_close_date, :date
    add_column :kanban_items, :score, :integer, default: 0
    add_column :kanban_items, :tags, :jsonb, null: false, default: []

    add_index :kanban_items, :source
    add_index :kanban_items, :temperature
  end
end
