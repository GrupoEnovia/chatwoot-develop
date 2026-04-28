json.payload do
  json.array! @attachments do |attachment|
    json.partial! 'api/v1/accounts/kanban/attachments/partials/attachment', formats: [:json], attachment: attachment
  end
end
