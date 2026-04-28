class Api::V1::Accounts::AiAgentMetricsController < Api::V1::Accounts::BaseController
  def index
    since = period_start
    agents = Current.account.ai_agents

    render json: {
      payload: {
        summary:  build_summary(agents, since),
        agents:   build_per_agent(agents, since),
        timeline: build_timeline(agents, since),
        protocols: build_protocol_distribution(agents, since)
      }
    }
  end

  def agent_stats
    agent = Current.account.ai_agents.find(params[:ai_agent_id])
    since = period_start

    render json: {
      payload: {
        summary:  build_summary([agent], since),
        timeline: build_timeline([agent], since),
        protocols: build_protocol_distribution([agent], since),
        recent_executions: recent_executions(agent)
      }
    }
  end

  private

  def period_start
    case params[:period]
    when 'today' then Time.current.beginning_of_day
    when 'month' then 30.days.ago
    else              7.days.ago
    end
  end

  def executions_scope(agents, since)
    AiAgentExecution.where(ai_agent: agents).where('created_at >= ?', since)
  end

  def build_summary(agents, since)
    execs = executions_scope(agents, since)
    convs = AiAgentConversation.where(ai_agent: agents).where('created_at >= ?', since)
    total = execs.count

    {
      total_agents:        agents.where(active: true).count,
      total_conversations: convs.count,
      active_conversations: AiAgentConversation.where(ai_agent: agents, state: 'active').count,
      total_executions:    total,
      success_count:       execs.where(status: 'success').count,
      error_count:         execs.where(status: 'error').count,
      success_rate:        total.zero? ? 100.0 : (execs.where(status: 'success').count * 100.0 / total).round(1),
      avg_duration_ms:     execs.average(:duration_ms)&.round || 0,
      protocols_triggered: execs.where.not(protocol_triggered: nil).count,
      messages_sent:       AiAgentConversation.where(ai_agent: agents).sum(:messages_sent),
      messages_received:   AiAgentConversation.where(ai_agent: agents).sum(:messages_received)
    }
  end

  def build_per_agent(agents, since)
    agents.map do |agent|
      execs = AiAgentExecution.where(ai_agent: agent).where('created_at >= ?', since)
      convs = AiAgentConversation.where(ai_agent: agent)
      total = execs.count

      {
        id:              agent.id,
        name:            agent.name,
        active:          agent.active,
        inbox:           agent.inbox&.name,
        conversations:   convs.count,
        active_convs:    convs.where(state: 'active').count,
        executions:      total,
        errors:          execs.where(status: 'error').count,
        success_rate:    total.zero? ? 100.0 : (execs.where(status: 'success').count * 100.0 / total).round(1),
        avg_duration_ms: execs.average(:duration_ms)&.round || 0,
        messages_sent:   convs.sum(:messages_sent)
      }
    end
  end

  def build_timeline(agents, since)
    AiAgentExecution
      .where(ai_agent: agents)
      .where('created_at >= ?', since)
      .group("DATE(created_at AT TIME ZONE 'UTC')", :status)
      .count
      .each_with_object([]) do |((date, status), count), arr|
        existing = arr.find { |e| e[:date] == date.to_s }
        if existing
          existing[status.to_sym] = count
        else
          arr << { date: date.to_s, status => count }
        end
      end
      .sort_by { |e| e[:date] }
  end

  def build_protocol_distribution(agents, since)
    AiAgentExecution
      .where(ai_agent: agents)
      .where('created_at >= ?', since)
      .where.not(protocol_triggered: nil)
      .group(:protocol_triggered)
      .count
      .map { |keyword, count| { keyword: keyword, count: count } }
      .sort_by { |e| -e[:count] }
  end

  def recent_executions(agent)
    AiAgentExecution
      .where(ai_agent: agent)
      .order(created_at: :desc)
      .limit(20)
      .map do |e|
        {
          id:                 e.id,
          status:             e.status,
          input_type:         e.input_type,
          duration_ms:        e.duration_ms,
          protocol_triggered: e.protocol_triggered,
          error_message:      e.error_message,
          created_at:         e.created_at
        }
      end
  end
end
