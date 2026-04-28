class Api::V1::Accounts::AiAgentProtocolsController < Api::V1::Accounts::BaseController
  before_action :set_agent
  before_action :set_protocol, only: [:update, :destroy]

  def index
    @protocols = @agent.ai_agent_protocols.order(:position)
    render json: { payload: @protocols.map { |p| protocol_json(p) } }
  end

  def create
    @protocol = @agent.ai_agent_protocols.create!(protocol_params)
    render json: { payload: protocol_json(@protocol) }, status: :created
  end

  def update
    @protocol.update!(protocol_params)
    render json: { payload: protocol_json(@protocol) }
  end

  def destroy
    @protocol.destroy!
    head :ok
  end

  private

  def set_agent
    @agent = Current.account.ai_agents.find(params[:ai_agent_id])
  end

  def set_protocol
    @protocol = @agent.ai_agent_protocols.find(params[:id])
  end

  def protocol_params
    params.require(:protocol).permit(
      :protocol_type, :label, :keyword, :phone_number, :auto_summarize, :position
    )
  end

  def protocol_json(p)
    {
      id:             p.id,
      protocol_type:  p.protocol_type,
      label:          p.label,
      keyword:        p.keyword,
      phone_number:   p.phone_number,
      auto_summarize: p.auto_summarize,
      position:       p.position
    }
  end
end
