json.id                    agent.id
json.name                  agent.name
json.company               agent.company
json.language              agent.language
json.timezone              agent.timezone
json.active                agent.active
json.message_buffer_seconds agent.message_buffer_seconds
json.reactivation_command  agent.reactivation_command
json.message_chunk_size    agent.message_chunk_size
json.llm_provider          agent.llm_provider
json.llm_model             agent.llm_model
json.tts_enabled           agent.tts_enabled
json.tts_voice_id          agent.tts_voice_id
json.prompt                agent.prompt
json.prompt_draft          agent.prompt_draft
json.has_draft             agent.has_draft?
json.prompt_version        agent.prompt_version
json.inbox_id              agent.inbox_id
json.inbox do
  if agent.inbox
    json.id   agent.inbox.id
    json.name agent.inbox.name
  else
    json.null!
  end
end
json.has_schedule   agent.ai_agent_schedule.present?
json.created_at     agent.created_at
json.updated_at     agent.updated_at
