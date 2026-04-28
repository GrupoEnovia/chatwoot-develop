json.id note.id
json.kanban_item_id note.kanban_item_id
json.content note.content
json.author do
  json.id note.author.id
  json.name note.author.name
  json.avatar_url note.author.avatar_url
end
json.created_at note.created_at.to_i
json.updated_at note.updated_at.to_i
