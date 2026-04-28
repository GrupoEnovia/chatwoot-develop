class Api::V1::Accounts::AiAgentScheduleController < Api::V1::Accounts::BaseController
  before_action :set_agent
  before_action :set_schedule

  def show
    render json: { payload: schedule_json }
  end

  def update
    @schedule.update!(schedule_params)
    render json: { payload: schedule_json }
  end

  def google_auth
    redirect_uri = google_callback_url
    state        = "#{params[:ai_agent_id]}:#{Current.account.id}"
    url          = AiAgent::GoogleCalendar::AuthService.authorization_url(redirect_uri, state: state)
    render json: { url: url }
  end

  def google_callback
    code  = params[:code]
    state = params[:state]
    agent_id, account_id = state.to_s.split(':')

    account = Account.find_by(id: account_id)
    agent   = account&.ai_agents&.find_by(id: agent_id)

    if agent && code.present?
      token_data = AiAgent::GoogleCalendar::AuthService.exchange_code(code, google_callback_url)
      schedule   = agent.ai_agent_schedule || agent.build_ai_agent_schedule
      schedule.update!(
        google_refresh_token_encrypted: token_data['refresh_token'],
        google_access_token_encrypted:  token_data['access_token'],
        google_token_expires_at:        Time.current + token_data['expires_in'].to_i.seconds
      )
      redirect_to "#{frontend_agent_url(account_id, agent_id)}?calendar=connected"
    else
      redirect_to "#{frontend_agent_url(account_id, agent_id)}?calendar=error"
    end
  rescue StandardError => e
    Rails.logger.error "[AiAgent] Google callback error: #{e.message}"
    redirect_to "#{frontend_agent_url(account_id, agent_id)}?calendar=error"
  end

  def google_disconnect
    @schedule.update!(
      google_refresh_token_encrypted: nil,
      google_access_token_encrypted:  nil,
      google_token_expires_at:        nil,
      google_calendar_id:             nil
    )
    render json: { payload: schedule_json }
  end

  def available_slots
    slots = AiAgent::GoogleCalendar::SlotsFinder.find(@schedule)
    render json: {
      payload: slots.map { |s|
        {
          start:       s[:start].iso8601,
          end:         s[:end].iso8601,
          start_label: s[:start].strftime('%A, %d/%m às %H:%M'),
          end_label:   s[:end].strftime('%H:%M')
        }
      }
    }
  end

  private

  def set_agent
    @agent = Current.account.ai_agents.find(params[:ai_agent_id])
  end

  def set_schedule
    @schedule = @agent.ai_agent_schedule || @agent.create_ai_agent_schedule!
  end

  def schedule_params
    params.require(:schedule).permit(
      :google_calendar_id, :slot_duration_minutes, :max_days_in_advance,
      :max_concurrent_bookings, :min_notice_minutes, :default_subject,
      weekly_windows: {}
    )
  end

  def schedule_json
    {
      id:                       @schedule.id,
      google_connected:         @schedule.google_connected?,
      google_calendar_id:       @schedule.google_calendar_id,
      slot_duration_minutes:    @schedule.slot_duration_minutes,
      max_days_in_advance:      @schedule.max_days_in_advance,
      max_concurrent_bookings:  @schedule.max_concurrent_bookings,
      min_notice_minutes:       @schedule.min_notice_minutes,
      default_subject:          @schedule.default_subject,
      weekly_windows:           @schedule.weekly_windows
    }
  end

  def google_callback_url
    "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/auth/google_calendar/callback"
  end

  def frontend_agent_url(account_id, agent_id)
    "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/app/accounts/#{account_id}/settings/ai-agents/#{agent_id}"
  end
end
