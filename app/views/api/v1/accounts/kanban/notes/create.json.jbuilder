json.payload do
  json.partial! 'api/v1/accounts/kanban/notes/partials/note', formats: [:json], note: @note
end
