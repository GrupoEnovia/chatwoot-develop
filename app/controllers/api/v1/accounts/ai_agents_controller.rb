class Api::V1::Accounts::AiAgentsController < Api::V1::Accounts::BaseController
  before_action :set_agent, only: %i[show update destroy publish_prompt save_draft playground prompt_assistant export]

  def index
    @agents = Current.account.ai_agents.includes(:inbox, :ai_agent_schedule).order(:name)
    render :index
  end

  def show
    render :show
  end

  def create
    @agent = Current.account.ai_agents.create!(agent_params)
    render :show, status: :created
  end

  def update
    @agent.update!(agent_params)
    render :show
  end

  def destroy
    @agent.destroy!
    head :ok
  end

  def publish_prompt
    @agent.publish_prompt!(params[:prompt], Current.user)
    render :show
  end

  def save_draft
    @agent.save_draft!(params[:prompt])
    render :show
  end

  def playground
    messages  = params[:messages] || []
    use_draft = params[:use_draft] == true || params[:use_draft] == 'true'
    response  = AiAgent::PlaygroundService.call(@agent, messages, use_draft: use_draft)
    render json: { payload: { response: response } }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def prompt_assistant
    result = AiAgent::PromptAssistantService.call(@agent)
    render json: { payload: result }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def export
    data     = AiAgent::ExportService.call(@agent)
    filename = "ai-agent-#{@agent.name.parameterize}-#{Date.current}.json"
    send_data data.to_json, filename: filename, type: 'application/json', disposition: 'attachment'
  end

  def import
    raw   = params[:agent_data]
    data  = raw.is_a?(String) ? JSON.parse(raw) : raw.to_unsafe_h
    agent = AiAgent::ImportService.call(Current.account, data, user: Current.user)
    @agent = agent
    render :show, status: :created
  rescue JSON::ParserError
    render json: { error: 'JSON inválido' }, status: :unprocessable_entity
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_agent
    @agent = Current.account.ai_agents.find(params[:id])
  end

  def agent_params
    params.require(:ai_agent).permit(
      :name, :company, :language, :timezone,
      :message_buffer_seconds, :active, :inbox_id,
      :llm_provider, :llm_model, :llm_api_key_encrypted,
      :tts_enabled, :tts_voice_id, :tts_api_key_encrypted,
      :reactivation_command, :message_chunk_size,
      prompt: {},
      summary_config: {}
    )
  end
end
