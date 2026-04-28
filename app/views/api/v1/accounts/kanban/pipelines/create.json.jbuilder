json.payload do
  json.partial! 'api/v1/accounts/kanban/pipelines/partials/pipeline', formats: [:json], pipeline: @pipeline
end
