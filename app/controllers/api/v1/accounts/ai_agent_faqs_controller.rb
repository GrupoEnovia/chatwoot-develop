class Api::V1::Accounts::AiAgentFaqsController < Api::V1::Accounts::BaseController
  before_action :set_agent
  before_action :set_faq, only: [:update, :destroy]

  def index
    @faqs = @agent.ai_agent_faqs.order(:category, :created_at)
    render json: { payload: @faqs.map { |f| faq_json(f) } }
  end

  def create
    @faq = @agent.ai_agent_faqs.create!(faq_params)
    render json: { payload: faq_json(@faq) }, status: :created
  end

  def update
    @faq.update!(faq_params)
    render json: { payload: faq_json(@faq) }
  end

  def destroy
    @faq.destroy!
    head :ok
  end

  def import
    rows = params[:rows]
    return head :unprocessable_entity unless rows.is_a?(Array)

    created = rows.filter_map do |row|
      next unless row[:question].present? && row[:answer].present?

      @agent.ai_agent_faqs.create!(
        category:  row[:category].presence || 'faq',
        situation: row[:situation],
        question:  row[:question],
        answer:    row[:answer]
      )
    end

    render json: { payload: { imported: created.size } }, status: :created
  end

  private

  def set_agent
    @agent = Current.account.ai_agents.find(params[:ai_agent_id])
  end

  def set_faq
    @faq = @agent.ai_agent_faqs.find(params[:id])
  end

  def faq_params
    params.require(:faq).permit(:category, :situation, :question, :answer, :active)
  end

  def faq_json(faq)
    {
      id:         faq.id,
      category:   faq.category,
      situation:  faq.situation,
      question:   faq.question,
      answer:     faq.answer,
      active:     faq.active,
      created_at: faq.created_at
    }
  end
end
