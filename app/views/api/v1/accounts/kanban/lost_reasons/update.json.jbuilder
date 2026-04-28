json.payload do
  json.partial! 'api/v1/accounts/kanban/lost_reasons/partials/reason', formats: [:json], reason: @reason
end
