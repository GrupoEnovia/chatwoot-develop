json.payload do
  json.array! @activities do |activity|
    json.partial! 'api/v1/accounts/kanban/activities/partials/activity', formats: [:json], activity: activity
  end
end
