class AiAgent::PlaygroundService
  MAX_HISTORY = 20

  def self.call(agent, messages, use_draft: false)
    new(agent, messages, use_draft: use_draft).call
  end

  def initialize(agent, messages, use_draft: false)
    @agent     = agent
    @messages  = Array(messages)
    @use_draft = use_draft
  end

  def call
    prompt_data = active_prompt
    system      = build_system(prompt_data)
    history     = @messages.last(MAX_HISTORY).map do |m|
      { role: m['role'] == 'assistant' ? 'assistant' : 'user', content: m['content'].to_s }
    end

    AiAgent::LlmService.call(@agent, { system: system, messages: history })
  end

  private

  def active_prompt
    if @use_draft && @agent.prompt_draft.present? && @agent.prompt_draft.any?
      @agent.prompt_draft
    else
      @agent.prompt
    end
  end

  def build_system(p)
    parts = []

    name    = p.dig('identity', 'name').presence || p['name'].presence || @agent.name
    company = p.dig('identity', 'company').presence || p['company'].presence || @agent.company
    parts << "Você é #{name}, assistente virtual de #{company}."

    objs = Array(p.dig('identity', 'objectives').presence || p['objectives'])
    if objs.any?
      parts << "Seus objetivos:\n#{objs.map.with_index(1) { |o, i| "#{i}. #{o}" }.join("\n")}"
    end

    if (biz = p['business']).present?
      parts << "\n## Negócio\n#{biz['name']} — #{biz['description']}\nPúblico: #{biz['target_audience']}"
    end

    prods = Array(p['products'])
    if prods.any?
      parts << "\n## Produtos/Serviços"
      prods.each { |pr| parts << "- **#{pr['name']}** (#{pr['value']}): #{pr['description']}" }
    end

    pers = Array(p['personality'])
    parts << "\n## Personalidade\n#{pers.join(', ')}." if pers.any?

    rules = Array(p['rules'])
    if rules.any?
      parts << "\n## Regras"
      rules.each.with_index(1) { |r, i| parts << "#{i}. #{r}" }
    end

    flow = Array(p['flow'])
    if flow.any?
      parts << "\n## Fluxo de Conversão"
      flow.each.with_index(1) do |step, i|
        parts << "**Etapa #{i}: #{step['title']}** — #{step['instruction']}"
      end
    end

    faqs = @agent.ai_agent_faqs.where(active: true).limit(60)
    if faqs.any?
      parts << "\n## Base de Conhecimento"
      faqs.each { |f| parts << "P: #{f.question}\nR: #{f.answer}" }
    end

    protos = @agent.ai_agent_protocols.order(:position)
    if protos.any?
      parts << "\n## Protocolos de Saída"
      protos.each { |pr| parts << "- Quando #{pr.label}: use a palavra-chave **#{pr.keyword}**" }
    end

    parts << "\n---\n⚠️ [MODO PLAYGROUND — conversa de teste, não afeta conversas reais]"

    parts.join("\n")
  end
end
