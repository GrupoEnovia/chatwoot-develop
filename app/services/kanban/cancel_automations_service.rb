class Kanban::CancelAutomationsService
  def initialize(item, stage_id = nil)
    @item     = item
    @stage_id = stage_id || item.stage_id
  end

  def perform
    executions = KanbanAutomationExecution
                 .pending
                 .for_item(@item.id)
                 .joins(kanban_automation_action: :kanban_automation)
                 .where(kanban_automations: { trigger_stage_id: @stage_id })

    count = executions.count
    return if count.zero?

    executions.update_all(status: 'cancelled')

    @item.kanban_activities.create!(
      action_type: 'automation_cancelled',
      metadata: {
        stage_id:    @stage_id,
        count:       count,
        description: "#{count} automação(ões) cancelada(s) ao sair da etapa"
      }
    )
  end
end
