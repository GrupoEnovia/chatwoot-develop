json.payload do
  json.partial! 'api/v1/accounts/kanban/tasks/partials/task', formats: [:json], task: @task
end
