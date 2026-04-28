class CreateAiAgentExecutions < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_agent_executions do |t|
      t.references :ai_agent,    null: false, foreign_key: true, index: true
      t.references :conversation, null: false, foreign_key: true, index: true
      t.string  :input_type,    null: false, default: 'text'  # text, audio, image, pdf
      t.text    :input_content
      t.text    :output_content
      t.integer :tokens_used,   default: 0
      t.integer :duration_ms,   default: 0
      t.string  :status,        null: false, default: 'success'  # success, error, skipped, buffered, protocol
      t.string  :protocol_triggered
      t.text    :error_message
      t.timestamps
    end

    add_index :ai_agent_executions, [:ai_agent_id, :created_at]
    add_index :ai_agent_executions, :status
  end
end
