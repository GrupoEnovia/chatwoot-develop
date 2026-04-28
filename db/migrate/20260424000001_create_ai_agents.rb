class CreateAiAgents < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_agents do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :inbox, foreign_key: true, index: true
      t.string  :name,        null: false
      t.string  :company
      t.string  :language,    default: 'pt-BR'
      t.string  :timezone,    default: 'America/Sao_Paulo'
      t.integer :message_buffer_seconds, default: 20, null: false
      t.boolean :active,      default: true, null: false
      t.jsonb   :prompt,      default: {}, null: false
      t.integer :prompt_version, default: 1, null: false
      t.string  :llm_provider, default: 'openai'
      t.string  :llm_model,   default: 'gpt-4o'
      t.string  :llm_api_key_encrypted
      t.boolean :tts_enabled, default: false, null: false
      t.string  :tts_voice_id
      t.string  :tts_api_key_encrypted
      t.timestamps
    end

    add_index :ai_agents, [:account_id, :inbox_id], unique: true
    add_index :ai_agents, [:account_id, :active]
  end
end
