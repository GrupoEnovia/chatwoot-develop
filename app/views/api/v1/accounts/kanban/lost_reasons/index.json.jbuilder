json.payload do
  json.array! @reasons do |reason|
    json.partial! 'api/v1/accounts/kanban/lost_reasons/partials/reason', formats: [:json], reason: reason
  end
end
