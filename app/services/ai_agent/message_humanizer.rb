class AiAgent::MessageHumanizer
  CHARS_PER_SECOND = 20
  MIN_DELAY        = 1
  MAX_DELAY        = 5

  def self.send_response(conversation, text, agent: nil, agent_user: nil)
    new(conversation, text, agent: agent, agent_user: agent_user).send_response
  end

  def initialize(conversation, text, agent: nil, agent_user: nil)
    @conversation = conversation
    @text         = text.to_s.strip
    @agent        = agent
    @agent_user   = agent_user
  end

  def send_response
    chunks = split_into_chunks(@text)
    chunks.each_with_index do |chunk, i|
      sleep(typing_delay(chunk)) if i.positive?
      send_chunk(chunk)
    end

    send_audio if @agent&.tts_enabled?
  end

  private

  def split_into_chunks(text)
    chunk_size = @agent&.message_chunk_size.to_i
    chunk_size = 300 if chunk_size < 50

    paragraphs = text.split(/\n{2,}/).map(&:strip).reject(&:blank?)
    return [text] unless paragraphs.size > 1

    result = []
    buffer = ''
    paragraphs.each do |para|
      if buffer.empty?
        buffer = para
      elsif (buffer.length + para.length) < chunk_size
        buffer = "#{buffer}\n\n#{para}"
      else
        result << buffer
        buffer = para
      end
    end
    result << buffer unless buffer.empty?
    result
  end

  def typing_delay(chunk)
    (chunk.length.to_f / CHARS_PER_SECOND).clamp(MIN_DELAY, MAX_DELAY)
  end

  def send_chunk(content)
    @conversation.messages.create!(
      account:      @conversation.account,
      inbox:        @conversation.inbox,
      message_type: :outgoing,
      content_type: :text,
      content:      content,
      private:      false,
      sender:       @agent_user
    )
  end

  def send_audio
    audio_data = AiAgent::TtsService.convert(@agent, @text)
    return unless audio_data

    message = @conversation.messages.create!(
      account:      @conversation.account,
      inbox:        @conversation.inbox,
      message_type: :outgoing,
      content_type: :text,
      content:      nil,
      private:      false,
      sender:       @agent_user
    )

    message.attachments.new(
      account_id: @conversation.account_id,
      file_type:  :audio,
      file: {
        io:           StringIO.new(audio_data),
        filename:     'resposta.mp3',
        content_type: 'audio/mpeg'
      }
    ).save!
  rescue StandardError => e
    Rails.logger.error "[AiAgent] Audio send error: #{e.message}"
  end
end
