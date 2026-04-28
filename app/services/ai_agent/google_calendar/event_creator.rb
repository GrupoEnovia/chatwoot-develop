class AiAgent::GoogleCalendar::EventCreator
  def self.create(schedule, datetime_str, contact: nil, subject: nil)
    new(schedule, datetime_str, contact: contact, subject: subject).create
  end

  def initialize(schedule, datetime_str, contact: nil, subject: nil)
    @schedule     = schedule
    @datetime_str = datetime_str
    @contact      = contact
    @subject      = subject
  end

  def create
    client     = AiAgent::GoogleCalendar::ApiClient.new(@schedule)
    start_time = Time.parse(@datetime_str).in_time_zone(@schedule.ai_agent.timezone)
    end_time   = start_time + @schedule.slot_duration_minutes.minutes

    event  = build_event(start_time, end_time)
    result = client.create_event(@schedule.google_calendar_id, event)

    {
      event_id:  result['id'],
      html_link: result['htmlLink'],
      start:     start_time,
      end:       end_time,
      subject:   event[:summary]
    }
  end

  private

  def build_event(start_time, end_time)
    event = {
      summary: @subject.presence || @schedule.default_subject.presence || 'Reunião',
      start:   { dateTime: start_time.iso8601, timeZone: @schedule.ai_agent.timezone },
      end:     { dateTime: end_time.iso8601,   timeZone: @schedule.ai_agent.timezone }
    }

    if @contact
      attendees = []
      attendees << { email: @contact.email } if @contact.email.present?
      event[:attendees]   = attendees if attendees.any?
      event[:description] = "Contato: #{@contact.name} — #{@contact.phone_number}"
    end

    event
  end
end
