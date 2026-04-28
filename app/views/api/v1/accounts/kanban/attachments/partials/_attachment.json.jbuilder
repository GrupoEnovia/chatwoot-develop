json.id attachment.id
json.kanban_item_id attachment.kanban_item_id
json.file_name attachment.file_name
json.file_size attachment.file_size
json.file_type attachment.file_type
json.url attachment.url
json.formatted_size attachment.formatted_size
json.image attachment.image?
json.uploaded_by do
  json.id attachment.uploaded_by.id
  json.name attachment.uploaded_by.name
  json.avatar_url attachment.uploaded_by.avatar_url
end
json.created_at attachment.created_at.to_i
