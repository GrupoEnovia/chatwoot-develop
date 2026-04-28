class AiAgentSchedule < ApplicationRecord
  belongs_to :ai_agent

  validates :slot_duration_minutes,   numericality: { greater_than: 0 }
  validates :max_days_in_advance,     numericality: { greater_than: 0 }
  validates :max_concurrent_bookings, numericality: { greater_than: 0 }
  validates :min_notice_minutes,      numericality: { greater_than_or_equal_to: 0 }

  WEEKDAYS = %w[sunday monday tuesday wednesday thursday friday saturday].freeze

  def google_connected?
    google_calendar_id.present? && google_refresh_token_encrypted.present?
  end

  def token_expired?
    google_token_expires_at.blank? || google_token_expires_at < 5.minutes.from_now
  end

  def windows_for(weekday_name)
    Array(weekly_windows[weekday_name.downcase])
  end
end
