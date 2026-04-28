class AiAgent::PromptAssistantService
  META_PROMPT = <<~PROMPT
    Você é um especialista em configuração de agentes de IA conversacionais para vendas e atendimento.
    Analise a configuração do agente abaixo e retorne uma avaliação técnica detalhada.

    Avalie criticamente:
    1. Clareza e especificidade das instruções (objetivos vagos = score baixo)
    2. Consistência interna (conflitos entre regras, fluxo e personalidade)
    3. Cobertura do fluxo de conversão (lacunas = pontos de confusão)
    4. Qualidade da base de conhecimento
    5. Riscos de comportamento indesejado

    Responda SOMENTE com JSON válido, sem markdown, no formato exato:
    {
      "score": <inteiro 0-100>,
      "summary": "<avaliação geral em 1-2 frases>",
      "issues": [
        { "section": "<seção>", "severity": "high|medium|low", "description": "<problema específico>" }
      ],
      "suggestions": [
        { "section": "<seção>", "suggestion": "<sugestão concreta>", "example": "<exemplo de como ficaria>" }
      ]
    }
  PROMPT

  def self.call(agent)
    new(agent).call
  end

  def initialize(agent)
    @agent = agent
  end

  def call
    config   = build_config_summary
    messages = [{ role: 'user', content: config }]
    raw      = AiAgent::LlmService.call(@agent, { system: META_PROMPT, messages: messages })

    json_str = raw.match(/\{[\s\S]*\}/)&.to_s || raw
    JSON.parse(json_str)
  rescue JSON::ParserError
    { score: 0, summary: 'Não foi possível analisar a resposta do modelo.', issues: [], suggestions: [] }
  end

  private

  def build_config_summary
    p        = @agent.prompt
    faqs     = @agent.ai_agent_faqs.where(active: true)
    protocols = @agent.ai_agent_protocols.order(:position)

    data = {
      identity:       p.dig('identity') || { name: p['name'], objectives: p['objectives'] },
      business:       p['business'],
      products_count: Array(p['products']).size,
      products:       Array(p['products']).first(3),
      personality:    p['personality'],
      rules:          p['rules'],
      flow_steps:     Array(p['flow']).map { |s| { title: s['title'], instruction: s['instruction'] } },
      faq_total:      faqs.count,
      faq_sample:     faqs.limit(5).map { |f| { q: f.question, a: f.answer } },
      protocols:      protocols.map { |pr| { type: pr.protocol_type, keyword: pr.keyword, label: pr.label } }
    }

    JSON.pretty_generate(data)
  end
end
