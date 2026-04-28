class AiAgent::GoogleCalendar::AuthService
  GOOGLE_AUTH_URL  = 'https://accounts.google.com/o/oauth2/v2/auth'
  GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'
  SCOPE            = 'https://www.googleapis.com/auth/calendar'

  def self.authorization_url(redirect_uri, state: nil)
    params = {
      client_id:     client_id,
      redirect_uri:  redirect_uri,
      response_type: 'code',
      scope:         SCOPE,
      access_type:   'offline',
      prompt:        'consent',
      state:         state
    }.compact

    "#{GOOGLE_AUTH_URL}?#{params.to_query}"
  end

  def self.exchange_code(code, redirect_uri)
    conn = Faraday.new(url: GOOGLE_TOKEN_URL) do |f|
      f.request :url_encoded
      f.response :json
    end

    response = conn.post do |req|
      req.body = {
        code:          code,
        client_id:     client_id,
        client_secret: client_secret,
        redirect_uri:  redirect_uri,
        grant_type:    'authorization_code'
      }
    end

    raise "Google token exchange failed: #{response.body}" unless response.success?

    response.body
  end

  def self.refresh_token(refresh_token_value)
    conn = Faraday.new(url: GOOGLE_TOKEN_URL) do |f|
      f.request :url_encoded
      f.response :json
    end

    response = conn.post do |req|
      req.body = {
        refresh_token: refresh_token_value,
        client_id:     client_id,
        client_secret: client_secret,
        grant_type:    'refresh_token'
      }
    end

    raise "Google token refresh failed: #{response.body}" unless response.success?

    response.body
  end

  def self.client_id
    ENV.fetch('GOOGLE_CALENDAR_CLIENT_ID') { raise 'GOOGLE_CALENDAR_CLIENT_ID not set' }
  end

  def self.client_secret
    ENV.fetch('GOOGLE_CALENDAR_CLIENT_SECRET') { raise 'GOOGLE_CALENDAR_CLIENT_SECRET not set' }
  end
end
