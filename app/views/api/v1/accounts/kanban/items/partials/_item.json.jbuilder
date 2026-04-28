json.id item.id
json.account_id item.account_id
json.pipeline_id item.pipeline_id
json.stage_id item.stage_id
json.conversation_id item.conversation_id
json.contact_phone item.contact_phone
json.title item.title
json.value item.value
json.position item.position
json.source item.source
json.temperature item.temperature
json.probability item.stage&.probability || item.probability
json.expected_close_date item.expected_close_date
json.score item.score
json.tags item.tags
json.won_at item.won_at&.to_i
json.lost_at item.lost_at&.to_i
json.status item.status
json.contact_id item.contact_id
json.cpf item.cpf
json.gender item.gender
json.birth_date item.birth_date
json.address item.address

json.tasks_count item.kanban_tasks.size
json.pending_tasks_count item.kanban_tasks.pending.size
json.attachments_count item.kanban_attachments.size

if item.assignee
  json.assignee do
    json.id item.assignee.id
    json.name item.assignee.name
    json.avatar_url item.assignee.avatar_url
  end
else
  json.assignee nil
end

if item.lost_reason
  json.lost_reason do
    json.id item.lost_reason.id
    json.name item.lost_reason.name
  end
else
  json.lost_reason nil
end

label_names = item.conversation&.cached_label_list_array || []
json.conversation_labels label_names

json.created_at item.created_at.to_i
json.updated_at item.updated_at.to_i
