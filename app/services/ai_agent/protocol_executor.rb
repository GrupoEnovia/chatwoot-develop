class AiAgent::ProtocolExecutor
  def self.execute(protocol, conversation, agent, summary_text: nil)
    new(protocol, conversation, agent, summary_text: summary_text).execute
  end

  def initialize(protocol, conversation, agent, summary_text: nil)
    @protocol     = protocol
    @conversation = conversation
    @agent        = agent
    @summary_text = summary_text
  end

  def execute
    pause_agent_conversation
    add_label
    send_summary if @protocol.auto_summarize && @summary_text.present?
    notify_phone if @protocol.phone_number.present?
  end

  private

  def pause_agent_conversation
    ai_conv = AiAgentConversation.find_by(
      ai_agent: @agent,
      conversation: @conversation
    )
    ai_conv&.transfer!(reason: @protocol.protocol_type)
  end

  def add_label
    label = "ia-#{@protocol.protocol_type}"
    @conversation.labels.push(label) unless @conversation.label_list.include?(label)
  rescue StandardError => e
    Rails.logger.warn "[AiAgent] Could not add label: #{e.message}"
  end

  def send_summary
    @conversation.messages.create!(
      account:      @conversation.account,
      inbox:        @conversation.inbox,
      message_type: :outgoing,
      content_type: :text,
      content:      "📋 *Resumo do atendimento IA:*\n#{@summary_text}",
      private:      true
    )
  end

  def notify_phone
    Rails.logger.info "[AiAgent] Protocol #{@protocol.label} triggered — notify #{@protocol.phone_number}"
  end
end
