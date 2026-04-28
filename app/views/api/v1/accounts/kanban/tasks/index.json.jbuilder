json.payload do
  json.array! @tasks do |task|
    json.partial! 'api/v1/accounts/kanban/tasks/partials/task', formats: [:json], task: task
  end
end
