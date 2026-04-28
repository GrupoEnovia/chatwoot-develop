class Channel::Uazapi < ApplicationRecord
  include Channelable

  self.table_name = 'channel_uazapi'

  EDITABLE_ATTRS = %i[uazapi_instance_name phone_number].freeze

  validates :uazapi_instance_name, presence: true, uniqueness: true

  has_secure_token :identifier

  after_create :provision_instance

  def name
    'Uazapi'
  end

  def api_base_url
    InstallationConfig.find_by(name: 'UAZAPI_BASE_URL')&.value.presence ||
      ENV.fetch('UAZAPI_BASE_URL', nil)
  end

  def admin_token
    InstallationConfig.find_by(name: 'UAZAPI_ADMIN_TOKEN')&.value.presence ||
      ENV.fetch('UAZAPI_ADMIN_TOKEN', nil)
  end

  def uazapi_enabled?
    enabled = InstallationConfig.find_by(name: 'UAZAPI_ENABLED')&.value
    enabled.to_s.downcase.in?(%w[true 1 yes])
  end

  def api
    @api ||= ChannelUazapi::Api.new(self)
  end

  private

  def provision_instance
    webhook_url = "#{ENV.fetch('FRONTEND_URL', '')}/webhooks/uazapi/#{identifier}"
    api.create_instance(webhook_url: webhook_url)
  rescue StandardError => e
    Rails.logger.error "Channel::Uazapi provision_instance error: #{e.message}"
  end
end
