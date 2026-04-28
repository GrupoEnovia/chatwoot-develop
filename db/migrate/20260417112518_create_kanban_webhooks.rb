class CreateKanbanWebhooks < ActiveRecord::Migration[7.0]
  def change
    create_table :kanban_webhooks do |t|
      t.bigint :account_id, null: false
      t.bigint :pipeline_id
      t.string :url, null: false
      t.jsonb :events, null: false, default: []
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :kanban_webhooks, :account_id
    add_index :kanban_webhooks, :pipeline_id
    add_index :kanban_webhooks, [:account_id, :active]
  end
end
