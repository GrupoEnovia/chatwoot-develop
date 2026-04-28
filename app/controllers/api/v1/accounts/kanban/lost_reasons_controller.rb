class Api::V1::Accounts::Kanban::LostReasonsController < Api::V1::Accounts::BaseController
  before_action :fetch_reason, only: [:update, :destroy]

  def index
    @reasons = Current.account.kanban_lost_reasons.ordered
  end

  def create
    @reason = Current.account.kanban_lost_reasons.new(reason_params)
    @reason.save!
  end

  def update
    @reason.update!(reason_params)
  end

  def destroy
    @reason.destroy!
    head :ok
  end

  private

  def fetch_reason
    @reason = Current.account.kanban_lost_reasons.find(params[:id])
  end

  def reason_params
    params.permit(:name, :active, :position)
  end
end
