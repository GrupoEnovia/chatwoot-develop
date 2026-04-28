class Webhooks::UazapiController < ActionController::API
  def process_payload
    channel = Channel::Uazapi.find_by(identifier: params[:identifier])
    return head :not_found unless channel

    inbox = channel.inbox
    ChannelUazapi::IncomingMessageService.new(
      inbox:  inbox,
      params: params.to_unsafe_hash.with_indifferent_access
    ).perform

    head :ok
  rescue StandardError => e
    Rails.logger.error "Webhooks::UazapiController error: #{e.message}"
    head :ok
  end
end
