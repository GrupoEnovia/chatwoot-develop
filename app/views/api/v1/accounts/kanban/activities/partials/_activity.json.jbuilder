json.id activity.id
json.kanban_item_id activity.kanban_item_id
json.action_type activity.action_type
json.metadata activity.metadata

if activity.author
  json.author do
    json.id activity.author.id
    json.name activity.author.name
    json.avatar_url activity.author.avatar_url
  end
else
  json.author nil
end

json.created_at activity.created_at.to_i
