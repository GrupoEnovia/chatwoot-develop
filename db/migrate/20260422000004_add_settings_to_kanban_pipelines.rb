class AddSettingsToKanbanPipelines < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_pipelines, :settings, :jsonb, default: {}, null: false
  end
end
