class CreateKanbanLostReasons < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_lost_reasons do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :kanban_lost_reasons, :account_id
    add_index :kanban_lost_reasons, %i[account_id active]
  end
end
