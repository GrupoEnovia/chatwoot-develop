class Api::V1::Accounts::Kanban::GoalsController < Api::V1::Accounts::BaseController
  def index
    year  = params[:year]&.to_i  || Date.current.year
    month = params[:month]&.to_i || Date.current.month
    @goals = Current.account.kanban_goals.for_month(year, month).includes(:assignee)
    render json: {
      payload: @goals.map { |g|
        { id: g.id, assignee_id: g.assignee_id, year: g.year, month: g.month,
          target_value: g.target_value.to_f, target_won: g.target_won,
          assignee: { id: g.assignee.id, name: g.assignee.name, avatar_url: g.assignee.avatar_url } }
      }
    }
  end

  def upsert
    year  = params[:year]&.to_i  || Date.current.year
    month = params[:month]&.to_i || Date.current.month
    goal  = Current.account.kanban_goals.find_or_initialize_by(
      assignee_id: params.require(:assignee_id),
      year: year,
      month: month
    )
    goal.update!(
      target_value: params[:target_value] || goal.target_value,
      target_won: params[:target_won] || goal.target_won
    )
    render json: { payload: { id: goal.id, assignee_id: goal.assignee_id, year: goal.year, month: goal.month,
                               target_value: goal.target_value.to_f, target_won: goal.target_won } }
  end
end
