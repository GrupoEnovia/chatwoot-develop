json.payload do
  json.array! @notes do |note|
    json.partial! 'api/v1/accounts/kanban/notes/partials/note', formats: [:json], note: note
  end
end
