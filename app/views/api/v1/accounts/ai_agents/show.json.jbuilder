json.payload do
  json.partial! 'api/v1/accounts/ai_agents/partials/agent', formats: [:json], agent: @agent
end
