class CreateKanbanBadges < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_badges do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :icon, null: false, default: '🏅'
      t.string :color, default: 'bg-slate-50 border-slate-200 text-slate-700 dark:bg-slate-900/20 dark:border-slate-700'
      t.string :condition_type, null: false
      t.decimal :condition_value, precision: 15, scale: 2, default: 0
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :kanban_badges, [:account_id, :position]
  end
end
