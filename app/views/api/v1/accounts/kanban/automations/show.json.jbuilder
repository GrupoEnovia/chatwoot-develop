json.payload do
  json.partial! 'api/v1/accounts/kanban/automations/partials/automation', formats: [:json], automation: @automation
end
