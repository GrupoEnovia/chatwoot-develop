class CreateKanbanStages < ActiveRecord::Migration[7.0]
  def change
    create_table :kanban_stages do |t|
      t.bigint :pipeline_id, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.string :color, default: '#6366f1'

      t.timestamps
    end

    add_index :kanban_stages, :pipeline_id
    add_index :kanban_stages, [:pipeline_id, :position]
  end
end
