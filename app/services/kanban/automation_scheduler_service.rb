class Kanban::AutomationSchedulerService
  def initialize(item, stage)
    @item  = item
    @stage = stage
  end

  def perform
    automations = KanbanAutomation
                  .for_pipeline(@item.pipeline_id)
                  .triggered_by(@stage.id)
                  .active
                  .includes(:kanban_automation_actions)

    return if automations.none?

    scheduled_count = 0

    automations.each do |automation|
      automation.kanban_automation_actions.active.ordered.each do |action|
        run_at = action.delay_minutes.minutes.from_now
        execution = KanbanAutomationExecution.create!(
          kanban_item:              @item,
          kanban_automation_action: action,
          status:                   'pending',
          scheduled_at:             run_at
        )
        Kanban::ExecuteAutomationActionJob.set(wait_until: run_at).perform_later(execution.id)
        scheduled_count += 1
      end
    end

    return unless scheduled_count.positive?

    @item.kanban_activities.create!(
      action_type: 'automation_scheduled',
      metadata: {
        stage_id:   @stage.id,
        stage_name: @stage.name,
        count:      scheduled_count,
        description: "#{scheduled_count} ação(ões) de automação agendada(s) para a etapa #{@stage.name}"
      }
    )
  end
end
