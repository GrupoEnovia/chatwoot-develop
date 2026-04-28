json.payload do
  json.array! @automations do |automation|
    json.partial! 'api/v1/accounts/kanban/automations/partials/automation', formats: [:json], automation: automation
  end
end
