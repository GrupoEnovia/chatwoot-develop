json.id task.id
json.kanban_item_id task.kanban_item_id
json.title task.title
json.description task.description
json.priority task.priority
json.start_date task.start_date
json.due_date task.due_date
json.due_at task.due_at&.to_i
json.completed task.completed?
json.completed_at task.completed_at&.to_i
json.overdue task.overdue?
json.is_recurring task.is_recurring
json.recurrence_frequency task.recurrence_frequency
json.recurrence_interval task.recurrence_interval
json.recurrence_end_date task.recurrence_end_date

if task.assignee
  json.assignee do
    json.id task.assignee.id
    json.name task.assignee.name
    json.avatar_url task.assignee.avatar_url
  end
else
  json.assignee nil
end

json.created_at task.created_at.to_i
json.updated_at task.updated_at.to_i
