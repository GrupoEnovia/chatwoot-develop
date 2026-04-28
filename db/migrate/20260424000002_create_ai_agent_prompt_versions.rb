class CreateAiAgentPromptVersions < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_agent_prompt_versions do |t|
      t.references :ai_agent, null: false, foreign_key: true, index: true
      t.integer :version,  null: false
      t.jsonb   :prompt,   null: false, default: {}
      t.references :created_by, foreign_key: { to_table: :users }, index: true
      t.timestamps
    end

    add_index :ai_agent_prompt_versions, [:ai_agent_id, :version], unique: true
  end
end
