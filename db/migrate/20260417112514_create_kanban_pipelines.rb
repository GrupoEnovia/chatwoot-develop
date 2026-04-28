class CreateKanbanPipelines < ActiveRecord::Migration[7.0]
  def change
    create_table :kanban_pipelines do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.text :description
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :kanban_pipelines, :account_id
    add_index :kanban_pipelines, [:account_id, :position]
  end
end
