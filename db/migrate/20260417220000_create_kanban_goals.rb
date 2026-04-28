class CreateKanbanGoals < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_goals do |t|
      t.bigint :account_id, null: false
      t.bigint :assignee_id, null: false
      t.integer :month, null: false   # 1-12
      t.integer :year, null: false
      t.decimal :target_value, precision: 15, scale: 2, default: 0
      t.integer :target_won, default: 0

      t.timestamps
    end

    add_index :kanban_goals, [:account_id, :assignee_id, :year, :month], unique: true
  end
end
