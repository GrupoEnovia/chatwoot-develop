class AiAgent::ImportService
  def self.call(account, data, user: nil)
    new(account, data, user: user).call
  end

  def initialize(account, data, user: nil)
    @account = account
    @data    = data.is_a?(Hash) ? data.deep_symbolize_keys : {}
    @user    = user
  end

  def call
    raise ArgumentError, 'Formato inválido' unless @data[:format].to_s.start_with?('chatwoot-ai-agent')

    ad = @data[:agent]
    raise ArgumentError, 'Dados do agente ausentes' unless ad.present?

    agent = @account.ai_agents.create!(
      name:                   "#{ad[:name]} (importado)",
      company:                ad[:company],
      language:               ad[:language].presence || 'pt-BR',
      timezone:               ad[:timezone].presence || 'America/Sao_Paulo',
      message_buffer_seconds: (ad[:message_buffer_seconds] || 20).to_i,
      reactivation_command:   ad[:reactivation_command].presence || '/ia',
      message_chunk_size:     (ad[:message_chunk_size] || 300).to_i,
      prompt:                 ad[:prompt] || {}
    )

    import_faqs(agent, Array(ad[:faqs]))
    import_protocols(agent, Array(ad[:protocols]))

    agent
  end

  private

  def import_faqs(agent, faqs)
    faqs.each do |f|
      agent.ai_agent_faqs.create!(
        category: f[:category].presence || 'faq',
        question: f[:question].to_s,
        answer:   f[:answer].to_s,
        active:   f.key?(:active) ? f[:active] : true
      )
    rescue ActiveRecord::RecordInvalid
      next
    end
  end

  def import_protocols(agent, protocols)
    protocols.each.with_index(1) do |p, i|
      agent.ai_agent_protocols.create!(
        protocol_type:  p[:protocol_type].presence || 'custom',
        label:          p[:label].to_s,
        keyword:        p[:keyword].to_s,
        phone_number:   p[:phone_number],
        auto_summarize: p.key?(:auto_summarize) ? p[:auto_summarize] : false,
        position:       (p[:position] || i).to_i
      )
    rescue ActiveRecord::RecordInvalid
      next
    end
  end
end
