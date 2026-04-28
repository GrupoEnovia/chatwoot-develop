class AiAgent::LlmService
  OPENAI_URL    = 'https://api.openai.com/v1/chat/completions'
  ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages'
  GEMINI_URL    = 'https://generativelanguage.googleapis.com/v1beta/models'

  def self.call(agent, prompt)
    new(agent, prompt).call
  end

  def initialize(agent, prompt)
    @agent  = agent
    @prompt = prompt # { system: String, messages: Array }
  end

  def call
    case @agent.llm_provider
    when 'anthropic' then call_anthropic
    when 'gemini'    then call_gemini
    else call_openai
    end
  end

  private

  def api_key
    @agent.llm_api_key_encrypted.presence || raise(ArgumentError, 'LLM API key not configured')
  end

  def call_openai
    messages = [{ role: 'system', content: @prompt[:system] }] + @prompt[:messages]

    conn = Faraday.new(url: OPENAI_URL) do |f|
      f.request :json
      f.response :json
      f.options.timeout = 60
    end

    response = conn.post do |req|
      req.headers['Authorization'] = "Bearer #{api_key}"
      req.headers['Content-Type']  = 'application/json'
      req.body = {
        model:       @agent.llm_model,
        messages:    messages,
        max_tokens:  2000,
        temperature: 0.7
      }
    end

    raise "OpenAI error: #{response.body}" unless response.success?

    response.body.dig('choices', 0, 'message', 'content').to_s.strip
  end

  def call_anthropic
    conn = Faraday.new(url: ANTHROPIC_URL) do |f|
      f.request :json
      f.response :json
      f.options.timeout = 60
    end

    response = conn.post do |req|
      req.headers['x-api-key']         = api_key
      req.headers['anthropic-version'] = '2023-06-01'
      req.headers['Content-Type']      = 'application/json'
      req.body = {
        model:      @agent.llm_model,
        system:     @prompt[:system],
        messages:   @prompt[:messages],
        max_tokens: 2000
      }
    end

    raise "Anthropic error: #{response.body}" unless response.success?

    response.body.dig('content', 0, 'text').to_s.strip
  end

  def call_gemini
    url  = "#{GEMINI_URL}/#{@agent.llm_model}:generateContent"
    conn = Faraday.new do |f|
      f.request :json
      f.response :json
      f.options.timeout = 60
    end

    contents = @prompt[:messages].map do |m|
      role = m[:role] == 'assistant' ? 'model' : 'user'
      { role: role, parts: [{ text: m[:content].to_s }] }
    end

    response = conn.post(url) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.params['key']           = api_key
      req.body = {
        system_instruction: { parts: [{ text: @prompt[:system].to_s }] },
        contents:           contents,
        generationConfig:   { temperature: 0.7, maxOutputTokens: 2000 }
      }
    end

    raise "Gemini error: #{response.body}" unless response.success?

    response.body.dig('candidates', 0, 'content', 'parts', 0, 'text').to_s.strip
  end
end
