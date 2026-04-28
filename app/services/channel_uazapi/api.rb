class ChannelUazapi::Api
  def initialize(channel)
    @channel = channel
  end

  def create_instance(webhook_url:)
    post('/instance/create', {
           instanceName: @channel.uazapi_instance_name,
           webhookUrl:   webhook_url,
           events:       %w[MESSAGES_UPSERT CONNECTION_UPDATE]
         })
  end

  def get_qr_code
    get("/instance/connect/#{@channel.uazapi_instance_name}")
  end

  def instance_info
    get("/instance/fetchInstances", { instanceName: @channel.uazapi_instance_name })
  end

  def send_text(phone_number, text)
    post("/message/sendText/#{@channel.uazapi_instance_name}", {
           number:  sanitize_phone(phone_number),
           text:    text
         })
  end

  def send_media(phone_number, url:, caption: nil, type: 'image')
    post("/message/sendMedia/#{@channel.uazapi_instance_name}", {
           number:  sanitize_phone(phone_number),
           mediatype: type,
           media:   url,
           caption: caption
         }.compact)
  end

  def delete_instance
    delete("/instance/delete/#{@channel.uazapi_instance_name}")
  end

  private

  def sanitize_phone(number)
    number.to_s.gsub(/\D/, '')
  end

  def base_url
    @channel.api_base_url.to_s.chomp('/')
  end

  def admin_token
    @channel.admin_token
  end

  def conn
    @conn ||= Faraday.new(url: base_url) do |f|
      f.request :json
      f.response :json
      f.options.timeout = 30
      f.headers['apikey'] = admin_token
    end
  end

  def get(path, params = {})
    resp = conn.get(path) { |r| r.params = params }
    raise "UAZAPI error #{resp.status}: #{resp.body}" unless resp.success?

    resp.body
  end

  def post(path, body = {})
    resp = conn.post(path) { |r| r.body = body }
    raise "UAZAPI error #{resp.status}: #{resp.body}" unless resp.success?

    resp.body
  end

  def delete(path)
    resp = conn.delete(path)
    raise "UAZAPI error #{resp.status}: #{resp.body}" unless resp.success?

    resp.body
  end
end
