class Api::V1::Accounts::Kanban::ActivitiesController < Api::V1::Accounts::BaseController
  before_action :fetch_item

  def index
    @activities = @item.kanban_activities.ordered
    @activities = @activities.where(action_type: params[:action_type]) if params[:action_type].present?
    @activities = @activities.where('created_at >= ?', params[:start_date]) if params[:start_date].present?
    @activities = @activities.where('created_at <= ?', params[:end_date]) if params[:end_date].present?
  end

  private

  def fetch_item
    pipeline = Current.account.kanban_pipelines.find(params[:pipeline_id])
    @item = pipeline.kanban_items.find(params[:item_id])
  end
end
