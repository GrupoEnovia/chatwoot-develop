class AiAgent::TtsService
  ELEVENLABS_URL = 'https://api.elevenlabs.io/v1/text-to-speech'

  def self.convert(agent, text)
    new(agent, text).convert
  end

  def initialize(agent, text)
    @agent = agent
    @text  = text.to_s.strip
  end

  def convert
    return nil unless enabled?
    return nil if @text.blank?

    conn = Faraday.new do |f|
      f.options.timeout = 45
    end

    response = conn.post("#{ELEVENLABS_URL}/#{@agent.tts_voice_id}") do |req|
      req.headers['xi-api-key']   = api_key
      req.headers['Accept']       = 'audio/mpeg'
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        text:           @text,
        model_id:       'eleven_multilingual_v2',
        voice_settings: { stability: 0.5, similarity_boost: 0.75 }
      }.to_json
    end

    return nil unless response.status == 200

    response.body
  rescue StandardError => e
    Rails.logger.error "[AiAgent] TTS error: #{e.message}"
    nil
  end

  private

  def enabled?
    @agent.tts_enabled? && @agent.tts_voice_id.present? && api_key.present?
  end

  def api_key
    @agent.tts_api_key_encrypted.presence
  end
end
