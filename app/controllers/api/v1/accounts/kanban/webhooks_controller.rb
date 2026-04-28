class Api::V1::Accounts::Kanban::WebhooksController < Api::V1::Accounts::BaseController
  before_action :fetch_webhook, only: [:show, :update, :destroy]

  def index
    @webhooks = Current.account.kanban_webhooks.for_account(Current.account.id)
    @webhooks = @webhooks.where(pipeline_id: params[:pipeline_id]) if params[:pipeline_id].present?
  end

  def show; end

  def create
    @webhook = Current.account.kanban_webhooks.new(webhook_params)
    @webhook.save!
  end

  def update
    @webhook.update!(webhook_params)
  end

  def destroy
    @webhook.destroy!
    head :ok
  end

  private

  def fetch_webhook
    @webhook = Current.account.kanban_webhooks.find(params[:id])
  end

  def webhook_params
    params.permit(:pipeline_id, :url, :active, events: [])
  end
end
