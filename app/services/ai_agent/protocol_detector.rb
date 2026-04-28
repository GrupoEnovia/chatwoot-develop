class AiAgent::ProtocolDetector
  def self.detect(response_text, protocols)
    new(response_text, protocols).detect
  end

  def initialize(response_text, protocols)
    @response_text = response_text.to_s
    @protocols     = protocols
  end

  def detect
    @protocols.find { |p| @response_text.include?(p.keyword) }
  end

  # Strips the protocol keyword line from the response
  def self.clean(response_text, protocol)
    return response_text unless protocol

    response_text.lines.reject { |line| line.strip == protocol.keyword }.join
  end
end
