class Api::V1::Accounts::Kanban::AutomationsController < Api::V1::Accounts::BaseController
  before_action :fetch_automation, only: [:show, :update, :destroy]

  # GET /kanban/automations?pipeline_id=X
  def index
    @automations = Current.account
                          .kanban_pipelines
                          .find(params.require(:pipeline_id))
                          .kanban_automations
                          .includes(:trigger_stage, :kanban_automation_actions)
                          .order(:id)
  end

  # GET /kanban/automations/:id
  def show; end

  # POST /kanban/automations
  def create
    pipeline = Current.account.kanban_pipelines.find(params.require(:pipeline_id))
    @automation = pipeline.kanban_automations.create!(automation_params)
  end

  # PATCH /kanban/automations/:id
  def update
    @automation.update!(automation_params)
  end

  # DELETE /kanban/automations/:id
  def destroy
    @automation.destroy!
    head :ok
  end

  private

  def fetch_automation
    @automation = Current.account
                         .kanban_pipelines
                         .joins(:kanban_automations)
                         .pick(:id)
    @automation = KanbanAutomation
                  .joins(:pipeline)
                  .where(pipelines: { account_id: Current.account.id })
                  .find(params[:id])
  end

  def automation_params
    params.permit(
      :name, :description, :trigger_stage_id, :active,
      :stop_on_reply, :stop_on_stage_change, :stop_on_human_takeover
    )
  end
end
