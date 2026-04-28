class Api::V1::Accounts::Kanban::AutomationExecutionsController < Api::V1::Accounts::BaseController
  def index
    pipeline = Current.account.kanban_pipelines.find(params.require(:pipeline_id))
    item     = pipeline.kanban_items.find(params.require(:item_id))

    @executions = KanbanAutomationExecution
                  .for_item(item.id)
                  .includes(kanban_automation_action: :kanban_automation)
                  .order(scheduled_at: :desc)
  end
end
