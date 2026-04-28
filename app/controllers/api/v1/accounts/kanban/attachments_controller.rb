class Api::V1::Accounts::Kanban::AttachmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_item
  before_action :fetch_attachment, only: [:destroy]

  def index
    @attachments = @item.kanban_attachments.ordered
  end

  def create
    @attachment = @item.kanban_attachments.new(attachment_params.merge(uploaded_by: Current.user))
    @attachment.save!
    @item.kanban_activities.create!(
      author: Current.user,
      action_type: 'file_attached',
      metadata: { file_name: @attachment.file_name }
    )
  end

  def destroy
    @attachment.destroy!
    head :ok
  end

  private

  def fetch_item
    pipeline = Current.account.kanban_pipelines.find(params[:pipeline_id])
    @item = pipeline.kanban_items.find(params[:item_id])
  end

  def fetch_attachment
    @attachment = @item.kanban_attachments.find(params[:id])
  end

  def attachment_params
    params.permit(:file_name, :file_size, :file_type, :url)
  end
end
