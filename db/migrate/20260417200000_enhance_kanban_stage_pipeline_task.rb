class EnhanceKanbanStagePipelineTask < ActiveRecord::Migration[7.1]
  def change
    # kanban_stages: add is_won, is_lost, probability
    add_column :kanban_stages, :is_won, :boolean, default: false, null: false
    add_column :kanban_stages, :is_lost, :boolean, default: false, null: false
    add_column :kanban_stages, :probability, :integer, default: 0, null: false

    # kanban_pipelines: add is_default, is_active, visibility fields
    add_column :kanban_pipelines, :is_default, :boolean, default: false, null: false
    add_column :kanban_pipelines, :is_active, :boolean, default: true, null: false
    add_column :kanban_pipelines, :visibility_type, :string, default: 'all', null: false
    add_column :kanban_pipelines, :visible_to_user_ids, :jsonb, default: []

    # kanban_tasks: add description and due_at (datetime)
    add_column :kanban_tasks, :description, :text
    add_column :kanban_tasks, :due_at, :datetime
  end
end
