json.payload do
  json.partial! 'api/v1/accounts/kanban/attachments/partials/attachment', formats: [:json], attachment: @attachment
end
