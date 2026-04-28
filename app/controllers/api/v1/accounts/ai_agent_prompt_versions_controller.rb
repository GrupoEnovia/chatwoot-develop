class Api::V1::Accounts::AiAgentPromptVersionsController < Api::V1::Accounts::BaseController
  before_action :set_agent

  def index
    versions = @agent.ai_agent_prompt_versions.limit(20)
    render json: {
      payload: versions.map do |v|
        {
          id:         v.id,
          version:    v.version,
          prompt:     v.prompt,
          created_by: v.created_by&.name,
          created_at: v.created_at
        }
      end
    }
  end

  private

  def set_agent
    @agent = Current.account.ai_agents.find(params[:ai_agent_id])
  end
end
