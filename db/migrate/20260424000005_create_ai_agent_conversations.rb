class CreateAiAgentConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_agent_conversations do |t|
      t.references :ai_agent,    null: false, foreign_key: true, index: true
      t.references :conversation, null: false, foreign_key: true, index: true
      t.references :contact,     foreign_key: true, index: true
      t.string  :state,          null: false, default: 'active'  # active, paused, transferred, ended
      t.string  :paused_reason
      t.integer :messages_received, default: 0, null: false
      t.integer :messages_sent,     default: 0, null: false
      t.timestamps
    end

    add_index :ai_agent_conversations, [:ai_agent_id, :conversation_id], unique: true
    add_index :ai_agent_conversations, [:ai_agent_id, :state]
  end
end
