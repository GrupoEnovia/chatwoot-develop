class AiAgent::ProcessMessageJob < ApplicationJob
  queue_as :ai_agent
  sidekiq_options retry: 2

  def perform(agent_id, conversation_id)
    agent        = ::AiAgent.find_by(id: agent_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless agent && conversation

    buffer       = AiAgent::MessageBuffer.new(conversation_id, agent.message_buffer_seconds)
    new_messages = buffer.pop_all
    buffer.release_lock

    return if new_messages.empty?

    ai_conv = AiAgentConversation.find_by(ai_agent: agent, conversation: conversation)
    return if ai_conv && ai_conv.state != 'active'

    started_at = Time.current
    run(agent, conversation, new_messages, started_at)
  end

  private

  def run(agent, conversation, new_messages, started_at)
    prompt   = AiAgent::PromptBuilder.build(agent, conversation, new_messages)
    response = AiAgent::LlmService.call(agent, prompt)
    duration = ((Time.current - started_at) * 1000).round

    protocols      = agent.ai_agent_protocols.order(:position)
    protocol       = AiAgent::ProtocolDetector.detect(response, protocols)
    clean_response = AiAgent::ProtocolDetector.clean(response, protocol)

    booking_result = try_create_booking(agent, conversation, clean_response)
    clean_response = booking_result[:response] if booking_result

    record_execution(agent, conversation, new_messages, response, duration,
                     protocol: protocol, status: 'success')

    if protocol
      AiAgent::ProtocolExecutor.execute(protocol, conversation, agent, summary_text: clean_response)
      AiAgent::MessageHumanizer.send_response(conversation, clean_response, agent: agent) if clean_response.present?
    else
      AiAgent::MessageHumanizer.send_response(conversation, clean_response, agent: agent)
    end

    update_stats(agent, conversation, new_messages.size)
  rescue StandardError => e
    Rails.logger.error "[AiAgent] ProcessMessageJob error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    duration = ((Time.current - started_at) * 1000).round
    record_execution(agent, conversation, new_messages, nil, duration,
                     status: 'error', error_message: e.message)
  end

  def try_create_booking(agent, conversation, response_text)
    match = response_text.match(/#AGENDAR\s+([^\s\n]+)/)
    return nil unless match

    datetime_str = match[1]
    schedule     = agent.ai_agent_schedule
    return nil unless schedule&.google_connected?

    contact = conversation.contact
    event   = AiAgent::GoogleCalendar::EventCreator.create(
      schedule, datetime_str,
      contact: contact,
      subject: schedule.default_subject.presence || "Reunião com #{contact&.name || 'cliente'}"
    )

    clean = response_text.gsub(/#AGENDAR\s+[^\s\n]+/, '').strip
    append = "\n\n✅ Reunião confirmada! #{event[:start].strftime('%A, %d/%m às %H:%M')}.\nLink: #{event[:html_link]}"

    { response: clean + append }
  rescue StandardError => e
    Rails.logger.error "[AiAgent] Booking error: #{e.message}"
    nil
  end

  def record_execution(agent, conversation, new_messages, response, duration,
                       protocol: nil, status: 'success', error_message: nil)
    AiAgentExecution.create!(
      ai_agent:           agent,
      conversation:       conversation,
      input_type:         'text',
      input_content:      new_messages.join("\n"),
      output_content:     response,
      duration_ms:        duration,
      status:             status,
      protocol_triggered: protocol&.keyword,
      error_message:      error_message
    )
  rescue StandardError => e
    Rails.logger.warn "[AiAgent] Could not record execution: #{e.message}"
  end

  def update_stats(agent, conversation, received_count)
    AiAgentConversation.where(ai_agent: agent, conversation: conversation).update_all(
      "messages_received = messages_received + #{received_count}, messages_sent = messages_sent + 1"
    )
  end
end
