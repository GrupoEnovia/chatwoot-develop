class AiAgent::PromptBuilder
  MAX_HISTORY = 30
  MAX_FAQS    = 60

  def self.build(agent, conversation, new_messages)
    new(agent, conversation, new_messages).build
  end

  def initialize(agent, conversation, new_messages)
    @agent        = agent
    @conversation = conversation
    @new_messages = new_messages
  end

  def build
    {
      system:   build_system_prompt,
      messages: build_history_messages + build_new_messages
    }
  end

  private

  def build_system_prompt
    p = @agent.prompt || {}
    parts = []

    parts << identity_section(p)
    parts << business_section(p)
    parts << products_section(p) if p['products'].present?
    parts << personality_section(p) if p['personality'].present?
    parts << rules_section(p) if p['rules'].present?
    parts << flow_section(p) if p['flow'].present?
    parts << faq_section
    parts << protocol_section
    parts << scheduling_section
    parts << context_section

    parts.compact.join("\n\n---\n\n")
  end

  def identity_section(p)
    lines = ['# IDENTIDADE']
    lines << "Você é #{p['name'].presence || @agent.name}, um assistente de IA."
    lines << "Empresa: #{p['company'].presence || @agent.company}" if p['company'].present? || @agent.company.present?
    lines << "Idioma: #{@agent.language}"
    objectives = Array(p['objectives']).reject(&:blank?)
    lines << "\nObjetivos:\n#{objectives.map { |o| "- #{o}" }.join("\n")}" if objectives.any?
    lines.join("\n")
  end

  def business_section(p)
    b = p['business'] || {}
    return nil if b.values.all?(&:blank?)

    lines = ['# NEGÓCIO']
    lines << "Nome: #{b['name']}" if b['name'].present?
    lines << "Descrição: #{b['description']}" if b['description'].present?
    lines << "Público-alvo: #{b['target_audience']}" if b['target_audience'].present?
    lines.join("\n")
  end

  def products_section(p)
    products = Array(p['products']).reject { |pr| pr['name'].blank? }
    return nil if products.empty?

    lines = ['# PRODUTOS / SERVIÇOS']
    products.each do |pr|
      lines << "\n**#{pr['name']}**"
      lines << "Descrição: #{pr['description']}" if pr['description'].present?
      lines << "Valor: #{pr['value']}" if pr['value'].present?
      lines << "Para: #{pr['target_audience']}" if pr['target_audience'].present?
    end
    lines.join("\n")
  end

  def personality_section(p)
    traits = Array(p['personality']).reject(&:blank?)
    return nil if traits.empty?

    "# PERSONALIDADE\n#{traits.map { |t| "- #{t}" }.join("\n")}"
  end

  def rules_section(p)
    rules = Array(p['rules']).reject(&:blank?)
    return nil if rules.empty?

    "# REGRAS\n#{rules.map { |r| "- #{r}" }.join("\n")}"
  end

  def flow_section(p)
    steps = Array(p['flow']).reject { |s| s['title'].blank? }
    return nil if steps.empty?

    lines = ['# FLUXO DE CONVERSÃO']
    steps.each_with_index do |step, i|
      lines << "\n## Passo #{i + 1}: #{step['title']}"
      lines << step['instruction'] if step['instruction'].present?
      lines << "Exemplo: #{step['example']}" if step['example'].present?

      Array(step['substeps']).each do |sub|
        lines << "  - #{sub['title']}: #{sub['instruction']}" if sub['title'].present?
      end

      Array(step['branches']).each do |branch|
        lines << "  → Se #{branch['condition']}: #{branch['action']}" if branch['condition'].present?
      end
    end
    lines.join("\n")
  end

  def faq_section
    faqs = @agent.ai_agent_faqs.where(active: true).limit(MAX_FAQS)
    return nil if faqs.empty?

    lines = ['# BASE DE CONHECIMENTO (FAQ / OBJEÇÕES)']
    faqs.group_by(&:category).each do |category, items|
      lines << "\n## #{category.upcase}"
      items.each do |faq|
        lines << "S: #{faq.situation}" if faq.situation.present?
        lines << "P: #{faq.question}"
        lines << "R: #{faq.answer}"
        lines << ''
      end
    end
    lines.join("\n")
  end

  def protocol_section
    protocols = @agent.ai_agent_protocols.order(:position)
    return nil if protocols.empty?

    lines = ['# PROTOCOLOS DE SAÍDA']
    lines << 'Quando a situação exigir, inclua a palavra-chave exata no final de sua mensagem:'
    protocols.each do |p|
      lines << "- #{p.keyword} → #{p.label} (tipo: #{p.protocol_type})"
    end
    lines << "\nIMPORTANTE: Inclua a palavra-chave sozinha em uma linha, sem mais texto após ela."
    lines.join("\n")
  end

  def scheduling_section
    schedule = @agent.ai_agent_schedule
    return nil unless schedule&.google_connected?

    has_meeting_protocol = @agent.ai_agent_protocols.any? { |p| p.protocol_type == 'meeting' }
    return nil unless has_meeting_protocol

    slots = AiAgent::GoogleCalendar::SlotsFinder.find(schedule, days: [schedule.max_days_in_advance, 7].min)
    return nil if slots.empty?

    lines = ['# HORÁRIOS DISPONÍVEIS PARA AGENDAMENTO']
    lines << 'Quando o cliente confirmar interesse em agendar, proponha os seguintes horários:'
    slots.first(5).each_with_index do |slot, i|
      lines << "#{i + 1}. #{slot[:start].strftime('%A, %d/%m às %H:%M')} — #{slot[:end].strftime('%H:%M')}"
    end
    lines << "\nQuando o cliente escolher um horário, confirme e inclua no final de sua mensagem:"
    lines << '#AGENDAR <datetime_iso8601>'
    lines << "Exemplo: #AGENDAR #{slots.first[:start].iso8601}"
    lines.join("\n")
  rescue StandardError => e
    Rails.logger.warn "[AiAgent] PromptBuilder scheduling_section error: #{e.message}"
    nil
  end

  def context_section
    contact = @conversation.contact
    lines = ['# CONTEXTO DA CONVERSA']
    lines << "ID da conversa: #{@conversation.id}"
    lines << "Canal: #{@conversation.inbox.channel_type}"
    lines << "Contato: #{contact.name}" if contact&.name.present?
    lines << "Telefone: #{contact.phone_number}" if contact&.phone_number.present?
    lines.join("\n")
  end

  def build_history_messages
    history = @conversation.messages
                           .where(message_type: [:incoming, :outgoing])
                           .where(private: false)
                           .where.not(content_type: :activity)
                           .order(:created_at)
                           .last(MAX_HISTORY)

    history.filter_map do |msg|
      next if msg.content.blank?

      role = msg.message_type == 'incoming' ? 'user' : 'assistant'
      { role: role, content: msg.content.to_s }
    end
  end

  def build_new_messages
    @new_messages.map { |content| { role: 'user', content: content.to_s } }
  end
end
