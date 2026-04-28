class ChannelUazapi::SendOnUazapiService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Uazapi
  end

  def perform_reply
    send_message
  end

  def send_message
    phone = message.conversation.contact_inbox.source_id
    if message.attachments.any?
      send_attachments(phone)
    else
      channel.api.send_text(phone, message.content.to_s) if message.content.present?
    end
  rescue StandardError => e
    Rails.logger.error "ChannelUazapi::SendOnUazapiService error: #{e.message}"
    message.update!(status: :failed, external_error: e.message)
  end

  def send_attachments(phone)
    message.attachments.each do |att|
      url = att.download_url
      type = attachment_media_type(att.file_type)
      caption = message.content.presence
      channel.api.send_media(phone, url: url, caption: caption, type: type)
    end
  end

  def attachment_media_type(file_type)
    case file_type.to_s
    when 'image'   then 'image'
    when 'video'   then 'video'
    when 'audio'   then 'audio'
    else 'document'
    end
  end
end
