json.payload do
  json.array! @actions do |action|
    json.partial! 'api/v1/accounts/kanban/automation_actions/partials/action', formats: [:json], action: action
  end
end
