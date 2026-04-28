class AiAgent::ExportService
  def self.call(agent)
    new(agent).call
  end

  def initialize(agent)
    @agent = agent
  end

  def call
    {
      format:      'chatwoot-ai-agent/v1',
      exported_at: Time.current.iso8601,
      agent: {
        name:                  @agent.name,
        company:               @agent.company,
        language:              @agent.language,
        timezone:              @agent.timezone,
        message_buffer_seconds: @agent.message_buffer_seconds,
        reactivation_command:  @agent.reactivation_command,
        message_chunk_size:    @agent.message_chunk_size,
        prompt:                @agent.prompt,
        faqs:                  export_faqs,
        protocols:             export_protocols
      }
    }
  end

  private

  def export_faqs
    @agent.ai_agent_faqs.map do |f|
      { category: f.category, question: f.question, answer: f.answer, active: f.active }
    end
  end

  def export_protocols
    @agent.ai_agent_protocols.order(:position).map do |p|
      {
        protocol_type:  p.protocol_type,
        label:          p.label,
        keyword:        p.keyword,
        phone_number:   p.phone_number,
        auto_summarize: p.auto_summarize,
        position:       p.position
      }
    end
  end
end
