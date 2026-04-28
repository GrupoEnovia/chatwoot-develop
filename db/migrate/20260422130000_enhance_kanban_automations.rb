class EnhanceKanbanAutomations < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_automations, :description, :text
    add_column :kanban_automations, :stop_on_reply, :boolean, default: true, null: false
    add_column :kanban_automations, :stop_on_stage_change, :boolean, default: true, null: false
    add_column :kanban_automations, :stop_on_human_takeover, :boolean, default: false, null: false
  end
end
