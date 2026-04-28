class AiAgent::GoogleCalendar::SlotsFinder
  MAX_SLOTS = 10

  def self.find(schedule, days: nil)
    new(schedule, days: days).find
  end

  def initialize(schedule, days: nil)
    @schedule = schedule
    @days     = days || schedule.max_days_in_advance
  end

  def find
    return [] unless @schedule.google_connected?

    client    = AiAgent::GoogleCalendar::ApiClient.new(@schedule)
    time_zone = @schedule.ai_agent.timezone
    now       = Time.current.in_time_zone(time_zone)
    min_time  = now + @schedule.min_notice_minutes.minutes
    max_time  = now + @days.days

    busy_times = fetch_busy_times(client, min_time, max_time)
    generate_slots(min_time, max_time, busy_times, time_zone)
  rescue StandardError => e
    Rails.logger.error "[AiAgent] SlotsFinder error: #{e.message}"
    []
  end

  private

  def fetch_busy_times(client, min_time, max_time)
    data = client.freebusy(@schedule.google_calendar_id, min_time, max_time)
    Array(data.dig('calendars', @schedule.google_calendar_id, 'busy')).map do |period|
      {
        start: Time.parse(period['start']),
        end:   Time.parse(period['end'])
      }
    end
  end

  def generate_slots(min_time, max_time, busy_times, time_zone)
    slots    = []
    duration = @schedule.slot_duration_minutes.minutes
    cursor   = min_time.beginning_of_hour + (min_time.min < 30 ? 0 : 30).minutes
    cursor  += 30.minutes while cursor < min_time

    while cursor < max_time && slots.size < MAX_SLOTS
      slot_end = cursor + duration
      weekday  = AiAgentSchedule::WEEKDAYS[cursor.wday]
      windows  = @schedule.windows_for(weekday)

      if within_windows?(cursor, slot_end, windows) && !overlaps_busy?(cursor, slot_end, busy_times)
        slots << { start: cursor, end: slot_end }
      end

      cursor += 30.minutes
    end

    slots
  end

  def within_windows?(slot_start, slot_end, windows)
    windows.any? do |w|
      window_start = parse_time_of_day(slot_start.to_date, w['start'], slot_start.time_zone)
      window_end   = parse_time_of_day(slot_start.to_date, w['end'],   slot_start.time_zone)
      slot_start >= window_start && slot_end <= window_end
    end
  end

  def overlaps_busy?(slot_start, slot_end, busy_times)
    busy_times.any? do |b|
      slot_start < b[:end] && slot_end > b[:start]
    end
  end

  def parse_time_of_day(date, time_str, tz)
    h, m = time_str.to_s.split(':').map(&:to_i)
    tz.local(date.year, date.month, date.day, h, m)
  end
end
