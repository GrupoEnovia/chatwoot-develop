class AiAgent::IncomingMessageProcessor
  def self.call(message)
    new(message).call
  rescue StandardError => e
    Rails.logger.error "[AiAgent] IncomingMessageProcessor error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def initialize(message)
    @message      = message
    @conversation = message.conversation
    @inbox        = message.inbox
  end

  def call
    return unless eligible?

    buffer = AiAgent::MessageBuffer.new(@conversation.id, @agent.message_buffer_seconds)
    buffer.push(message_content)

    return unless buffer.acquire_lock

    AiAgent::ProcessMessageJob.set(wait: @agent.message_buffer_seconds.seconds)
                              .perform_later(@agent.id, @conversation.id)
  end

  private

  def eligible?
    return false unless @message.incoming?
    return false if @message.private?
    return false if @message.content_type == 'activity'
    return false if message_content.blank?
    return false if @conversation.label_list.include?('ia_desligada')

    @agent = ::AiAgent.find_by(inbox: @inbox, active: true)
    return false unless @agent

    ai_conv = find_or_create_ai_conversation
    ai_conv.state == 'active'
  end

  def find_or_create_ai_conversation
    AiAgentConversation.find_or_create_by!(
      ai_agent:     @agent,
      conversation: @conversation
    ) do |c|
      c.contact = @conversation.contact
      c.state   = 'active'
    end
  end

  def message_content
    @message_content ||= @message.content.to_s.strip
  end
end
