class Api::V1::Accounts::Kanban::PipelinesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline, only: [:show, :update, :destroy]

  def index
    @pipelines = Current.account.kanban_pipelines.ordered
  end

  def show; end

  def create
    @pipeline = Current.account.kanban_pipelines.new(pipeline_params)
    @pipeline.save!
  end

  def update
    # If marking as default, unset other defaults
    if pipeline_params[:is_default] == true || pipeline_params[:is_default] == 'true'
      Current.account.kanban_pipelines.where.not(id: @pipeline.id).update_all(is_default: false)
    end
    @pipeline.update!(pipeline_params)
  end

  def destroy
    @pipeline.destroy!
    head :ok
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.kanban_pipelines.find(params[:id])
  end

  def pipeline_params
    p = params.permit(
      :name, :description, :position, :is_default, :is_active,
      :visibility_type, visible_to_user_ids: [], settings: {}
    )
    p
  end
end
