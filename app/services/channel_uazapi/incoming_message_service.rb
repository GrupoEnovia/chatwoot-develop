class ChannelUazapi::IncomingMessageService
  pattr_initialize [:inbox!, :params!]

  def perform
    return unless message_type_upsert?
    return if outgoing_echo?

    set_contact
    set_conversation
    create_message
  end

  private

  def message_type_upsert?
    params[:event].to_s.downcase.in?(%w[messages_upsert messages.upsert])
  end

  def outgoing_echo?
    params.dig(:data, :key, :fromMe) == true
  end

  def raw_message
    @raw_message ||= params[:data] || params
  end

  def sender_phone
    jid = raw_message.dig(:key, :remoteJid).to_s
    jid.split('@').first.gsub(/\D/, '')
  end

  def sender_name
    raw_message.dig(:pushName).presence || sender_phone
  end

  def message_body
    raw_message.dig(:message, :conversation).presence ||
      raw_message.dig(:message, :extendedTextMessage, :text).presence ||
      ''
  end

  def message_id
    raw_message.dig(:key, :id).to_s
  end

  def set_contact
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: sender_phone,
      inbox: @inbox,
      contact_attributes: { name: sender_name, phone_number: "+#{sender_phone}" }
    ).perform

    @contact_inbox = contact_inbox
    @contact        = contact_inbox.contact
  end

  def set_conversation
    @conversation = @contact_inbox.conversations
                                  .where.not(status: :resolved)
                                  .last

    return if @conversation

    @conversation = ::Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id:   @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    )
  end

  def create_message
    return if message_body.blank? && media_url.blank?
    return if @conversation.messages.find_by(source_id: message_id)

    msg = @conversation.messages.create!(
      content:      message_body.presence,
      account_id:   @inbox.account_id,
      inbox_id:     @inbox.id,
      message_type: :incoming,
      sender:       @contact,
      source_id:    message_id
    )

    attach_media(msg) if media_url.present?
  end

  def media_url
    @media_url ||= raw_message.dig(:message, :imageMessage, :url).presence ||
                   raw_message.dig(:message, :videoMessage, :url).presence ||
                   raw_message.dig(:message, :audioMessage, :url).presence ||
                   raw_message.dig(:message, :documentMessage, :url).presence
  end

  def media_type
    return :image    if raw_message.dig(:message, :imageMessage).present?
    return :video    if raw_message.dig(:message, :videoMessage).present?
    return :audio    if raw_message.dig(:message, :audioMessage).present?
    return :file     if raw_message.dig(:message, :documentMessage).present?

    :file
  end

  def attach_media(msg)
    msg.attachments.create!(
      account_id: msg.account_id,
      file_type:  media_type,
      external_url: media_url
    )
  rescue StandardError => e
    Rails.logger.error "ChannelUazapi media attachment error: #{e.message}"
  end
end
