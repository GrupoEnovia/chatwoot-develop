class CreateAiAgentProtocols < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_agent_protocols do |t|
      t.references :ai_agent, null: false, foreign_key: true, index: true
      t.string  :protocol_type, null: false  # human, qualified, meeting, unqualified, custom
      t.string  :label,         null: false
      t.string  :keyword,       null: false
      t.string  :phone_number
      t.boolean :auto_summarize, default: true, null: false
      t.integer :position,      default: 0, null: false
      t.timestamps
    end
  end
end
