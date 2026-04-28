class Api::V1::Accounts::Kanban::GlobalItemsController < Api::V1::Accounts::BaseController
  def index
    @items = Current.account.kanban_items.includes(:pipeline, :stage, :assignee)
    @items = @items.where(conversation_id: params[:conversation_id]) if params[:conversation_id].present?
    @items = @items.ordered
    render json: {
      payload: @items.map { |item|
        {
          id: item.id,
          title: item.title,
          value: item.value,
          status: item.status,
          stage_id: item.stage_id,
          pipeline_id: item.pipeline_id,
          conversation_id: item.conversation_id,
          contact_phone: item.contact_phone,
          temperature: item.temperature,
          source: item.source,
          score: item.score,
          pipeline_name: item.pipeline.name,
          stage_name: item.stage.name,
          stage_color: item.stage.color,
          assignee: item.assignee ? { id: item.assignee.id, name: item.assignee.name, avatar_url: item.assignee.avatar_url } : nil,
          created_at: item.created_at.to_i,
          updated_at: item.updated_at.to_i,
          stage_changed_at: item.updated_at.to_i
        }
      }
    }
  end
end
