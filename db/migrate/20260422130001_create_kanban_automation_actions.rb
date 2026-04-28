class CreateKanbanAutomationActions < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_automation_actions do |t|
      t.references :kanban_automation, null: false, foreign_key: true, index: true
      t.string     :action_type,   null: false
      t.integer    :position,      null: false, default: 0
      t.integer    :delay_minutes, null: false, default: 0
      t.string     :delay_type,    null: false, default: 'minutes'
      t.boolean    :active,        null: false, default: true
      t.jsonb      :config,        null: false, default: {}
      t.timestamps
    end

    add_index :kanban_automation_actions, %i[kanban_automation_id position]
    add_index :kanban_automation_actions, :action_type
  end
end
