class CreateKanbanAutomations < ActiveRecord::Migration[7.0]
  def change
    create_table :kanban_automations do |t|
      t.bigint :pipeline_id, null: false
      t.string :name, null: false
      t.bigint :trigger_stage_id, null: false
      t.bigint :action_stage_id
      t.jsonb :conditions, null: false, default: {}
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :kanban_automations, :pipeline_id
    add_index :kanban_automations, :trigger_stage_id
    add_index :kanban_automations, :action_stage_id
    add_index :kanban_automations, [:pipeline_id, :active]
  end
end
