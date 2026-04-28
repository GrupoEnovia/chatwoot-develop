class Api::V1::Accounts::Kanban::AutomationActionsController < Api::V1::Accounts::BaseController
  before_action :fetch_automation
  before_action :fetch_action, only: [:update, :destroy]

  def index
    @actions = @automation.kanban_automation_actions.ordered
  end

  def create
    @action = @automation.kanban_automation_actions.create!(action_params)
  end

  def update
    @action.update!(action_params)
  end

  def destroy
    @action.destroy!
    head :ok
  end

  private

  def fetch_automation
    @automation = KanbanAutomation
                  .joins(:pipeline)
                  .where(kanban_pipelines: { account_id: Current.account.id })
                  .find(params[:automation_id])
  end

  def fetch_action
    @action = @automation.kanban_automation_actions.find(params[:id])
  end

  def action_params
    p = params.permit(
      :action_type, :position, :delay_minutes, :delay_type, :active,
      config: {}
    )
    p[:config] = params[:config].to_unsafe_h if params[:config].present?
    p
  end
end
