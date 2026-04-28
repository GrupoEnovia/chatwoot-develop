json.payload do
  json.array! @executions do |execution|
    json.id execution.id
    json.status execution.status
    json.scheduled_at execution.scheduled_at&.to_i
    json.executed_at execution.executed_at&.to_i
    json.error_message execution.error_message
    json.result execution.result

    json.action do
      action = execution.kanban_automation_action
      json.id action.id
      json.action_type action.action_type
      json.position action.position
      json.delay_minutes action.delay_minutes
      json.delay_type action.delay_type
    end

    json.automation do
      automation = execution.kanban_automation_action.kanban_automation
      json.id automation.id
      json.name automation.name
    end

    json.created_at execution.created_at.to_i
  end
end
