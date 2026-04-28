json.payload do
  json.partial! 'api/v1/accounts/kanban/stages/partials/stage', formats: [:json], stage: @stage
end
