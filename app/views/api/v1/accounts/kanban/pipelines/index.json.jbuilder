json.payload do
  json.array! @pipelines do |pipeline|
    json.partial! 'api/v1/accounts/kanban/pipelines/partials/pipeline', formats: [:json], pipeline: pipeline
  end
end
