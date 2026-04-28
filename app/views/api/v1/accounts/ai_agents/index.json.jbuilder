json.payload do
  json.array! @agents do |agent|
    json.partial! 'api/v1/accounts/ai_agents/partials/agent', formats: [:json], agent: agent
  end
end
