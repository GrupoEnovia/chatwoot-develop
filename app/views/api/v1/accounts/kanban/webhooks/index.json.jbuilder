json.payload do
  json.array! @webhooks do |webhook|
    json.partial! 'api/v1/accounts/kanban/webhooks/partials/webhook', formats: [:json], webhook: webhook
  end
end
