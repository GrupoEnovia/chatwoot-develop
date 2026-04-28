class Api::V1::Accounts::Kanban::StagesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline
  before_action :fetch_stage, only: [:show, :update, :destroy, :reorder]

  def index
    @stages = @pipeline.kanban_stages.ordered
  end

  def show; end

  def create
    @stage = @pipeline.kanban_stages.new(stage_params)
    @stage.save!
  end

  def update
    @stage.update!(stage_params)
  end

  def destroy
    @stage.destroy!
    head :ok
  end

  def reorder
    @stage.update!(position: params.require(:position))
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.kanban_pipelines.find(params[:pipeline_id])
  end

  def fetch_stage
    @stage = @pipeline.kanban_stages.find(params[:id])
  end

  def stage_params
    params.permit(:name, :position, :color, :is_won, :is_lost, :probability)
  end
end
