json.id automation.id
json.pipeline_id automation.pipeline_id
json.trigger_stage_id automation.trigger_stage_id
json.trigger_stage_name automation.trigger_stage&.name
json.name automation.name
json.description automation.description
json.active automation.active
json.stop_on_reply automation.stop_on_reply
json.stop_on_stage_change automation.stop_on_stage_change
json.stop_on_human_takeover automation.stop_on_human_takeover

json.actions automation.kanban_automation_actions.ordered do |action|
  json.id action.id
  json.action_type action.action_type
  json.position action.position
  json.delay_minutes action.delay_minutes
  json.delay_type action.delay_type
  json.active action.active
  json.config action.config
  json.created_at action.created_at.to_i
end

json.created_at automation.created_at.to_i
json.updated_at automation.updated_at.to_i
