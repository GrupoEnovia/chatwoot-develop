class CreateAiAgentFaqs < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_agent_faqs do |t|
      t.references :ai_agent, null: false, foreign_key: true, index: true
      t.string :category,  null: false, default: 'faq'  # faq, objection, context
      t.text   :situation
      t.text   :question,  null: false
      t.text   :answer,    null: false
      t.boolean :active,   default: true, null: false
      t.timestamps
    end

    add_index :ai_agent_faqs, [:ai_agent_id, :category]
  end
end
