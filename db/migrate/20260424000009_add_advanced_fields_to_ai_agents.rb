class AddAdvancedFieldsToAiAgents < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_agents, :prompt_draft,          :jsonb,   default: {}, null: false
    add_column :ai_agents, :reactivation_command,  :string,  default: '/ia'
    add_column :ai_agents, :message_chunk_size,    :integer, default: 300, null: false
    add_column :ai_agents, :summary_config,        :jsonb,   default: {}, null: false
  end
end
