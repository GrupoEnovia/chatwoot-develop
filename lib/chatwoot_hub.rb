class ChatwootHub
  DEFAULT_BASE_URL = 'https://www.google.com'.freeze

  def self.base_url
    DEFAULT_BASE_URL
  end

  def self.installation_identifier
    identifier = InstallationConfig.find_by(name: 'INSTALLATION_IDENTIFIER')&.value
    identifier ||= InstallationConfig.create!(name: 'INSTALLATION_IDENTIFIER', value: SecureRandom.uuid).value
    identifier
  end

  def self.billing_url
    '#'
  end

  # Always reports enterprise plan so all features stay enabled
  def self.pricing_plan
    'enterprise'
  end

  def self.pricing_plan_quantity
    999_999
  end

  def self.support_config
    { support_website_token: nil, support_script_url: nil, support_identifier_hash: nil }
  end

  # All outgoing calls to chatwoot.com are disabled
  def self.sync_with_hub       = {}
  def self.register_instance(*) = nil
  def self.send_push(*)         = nil
  def self.emit_event(*)        = nil
end

ChatwootHub.singleton_class.prepend_mod_with('ChatwootHub')
