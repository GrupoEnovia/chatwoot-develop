class Api::V1::Accounts::Kanban::GamificationController < Api::V1::Accounts::BaseController
  def rankings
    range = period_range
    users = Current.account.users.where(account_users: { role: %w[agent administrator] })
    base  = Current.account.kanban_items

    payload = users.map do |user|
      items_all = base.where(assignee_id: user.id)
      won  = range ? items_all.where(won_at: range) : items_all.where.not(won_at: nil)
      lost = range ? items_all.where(lost_at: range) : items_all.where.not(lost_at: nil)
      open = items_all.where(won_at: nil, lost_at: nil)

      won_count   = won.count
      total_value = won.sum(:value).to_f
      max_deal    = won.maximum(:value).to_f
      closeable   = won_count + lost.count
      conv_rate   = closeable > 0 ? (won_count.to_f / closeable * 100).round(1) : 0.0

      # Score: cada venda vale 100pts + bônus de R$ 1.000 = 1pt
      # Purely commercial — only won deals count
      points = (won_count * 100) + (total_value / 1000).to_i

      {
        agent:  { id: user.id, name: user.name, avatar_url: user.avatar_url, email: user.email },
        stats:  {
          total: items_all.count,
          won:   won_count,
          lost:  lost.count,
          open:  open.count,
          value: total_value,
          max_deal_value: max_deal,
          conversion_rate: conv_rate,
        },
        points: points,
      }
    end

    payload.select! { |a| a[:stats][:won] > 0 }
    payload.sort_by! { |a| [-a[:points], -a[:stats][:won], -a[:stats][:value]] }

    render json: { payload: payload }
  end

  def overview
    account = Current.account
    range   = period_range
    now     = Time.current

    all_items  = account.kanban_items
    won_scope  = range ? all_items.where(won_at: range) : all_items.where.not(won_at: nil)
    new_scope  = range ? all_items.where(created_at: range) : all_items

    # Period-independent totals
    total_open = all_items.where(won_at: nil, lost_at: nil).count
    total_won  = all_items.where.not(won_at: nil).count
    total_lost = all_items.where.not(lost_at: nil).count

    # Fixed recent windows regardless of selected period (for comparison)
    today_won = all_items.where(won_at: now.beginning_of_day..now.end_of_day)
    week_won  = all_items.where(won_at: now.beginning_of_week..now.end_of_week)
    month_won = all_items.where(won_at: now.beginning_of_month..now.end_of_month)

    render json: {
      payload: {
        period:  { won: won_scope.count, new: new_scope.count, value: won_scope.sum(:value).to_f },
        today:   { won: today_won.count, value: today_won.sum(:value).to_f },
        week:    { won: week_won.count,  value: week_won.sum(:value).to_f },
        month:   { won: month_won.count, value: month_won.sum(:value).to_f },
        total:   { open: total_open, won: total_won, lost: total_lost },
      }
    }
  end

  def recent_wins
    range = period_range
    wins  = Current.account.kanban_items
              .then { |s| range ? s.where(won_at: range) : s.where.not(won_at: nil) }
              .includes(:assignee, :stage, :pipeline)
              .order(won_at: :desc)
              .limit(params[:limit]&.to_i&.clamp(1, 100) || 30)

    render json: {
      payload: wins.map { |item|
        {
          id:            item.id,
          title:         item.title,
          value:         item.value.to_f,
          won_at:        item.won_at.to_i,
          pipeline_name: item.pipeline&.name,
          stage_name:    item.stage&.name,
          stage_color:   item.stage&.color,
          assignee:      item.assignee ? {
            id: item.assignee.id, name: item.assignee.name, avatar_url: item.assignee.avatar_url
          } : nil,
        }
      }
    }
  end

  def timeline
    range = period_range
    acts  = KanbanActivity
              .joins(:kanban_item)
              .where(kanban_items: { account_id: Current.account.id })
              .where(action_type: %w[won lost reopened])
              .then { |s| range ? s.where(created_at: range) : s }
              .includes(kanban_item: %i[assignee pipeline stage])
              .order(created_at: :desc)
              .limit(params[:limit]&.to_i&.clamp(1, 100) || 50)

    render json: {
      payload: acts.map { |a|
        item = a.kanban_item
        {
          id:          a.id,
          action_type: a.action_type,
          created_at:  a.created_at.to_i,
          metadata:    a.metadata,
          item: {
            id:            item.id,
            title:         item.title,
            value:         item.value.to_f,
            pipeline_name: item.pipeline&.name,
            stage_color:   item.stage&.color,
          },
          agent: item.assignee ? {
            id:         item.assignee.id,
            name:       item.assignee.name,
            avatar_url: item.assignee.avatar_url,
          } : nil,
        }
      }
    }
  end

  def global_goals
    cfg = (Current.account.settings || {})['kanban_gamification'] || {}
    render json: {
      payload: {
        team_goal_value:  cfg['team_goal_value'].to_f,
        team_goal_won:    cfg['team_goal_won'].to_i,
        scoring_rule:     cfg['scoring_rule'] || 'won_only',
      }
    }
  end

  def update_global_goals
    settings = Current.account.settings || {}
    settings['kanban_gamification'] ||= {}
    cfg = settings['kanban_gamification']
    cfg['team_goal_value']  = params[:team_goal_value].to_f  if params.key?(:team_goal_value)
    cfg['team_goal_won']    = params[:team_goal_won].to_i    if params.key?(:team_goal_won)
    cfg['scoring_rule']     = params[:scoring_rule]          if params.key?(:scoring_rule)
    Current.account.update_column(:settings, settings)
    render json: { payload: cfg.slice('team_goal_value', 'team_goal_won', 'scoring_rule') }
  end

  private

  # Returns a Range for won_at / lost_at / created_at filtering.
  # Returns nil for all-time (no filter).
  def period_range
    now = Time.current
    case params[:period]
    when 'today'  then now.beginning_of_day..now.end_of_day
    when 'week'   then now.beginning_of_week..now.end_of_week
    when 'month'  then now.beginning_of_month..now.end_of_month
    when 'year'   then now.beginning_of_year..now.end_of_year
    when 'custom'
      from = params[:date_from].present? ? Time.zone.parse(params[:date_from]).beginning_of_day : 1.year.ago
      to   = params[:date_to].present?   ? Time.zone.parse(params[:date_to]).end_of_day          : now
      from..to
    else
      nil
    end
  end
end
