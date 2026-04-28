class Api::V1::Accounts::Kanban::BadgesController < Api::V1::Accounts::BaseController
  before_action :require_admin!, only: [:create, :update, :destroy, :seed]
  before_action :fetch_badge, only: [:update, :destroy]

  def index
    KanbanBadge.seed_for_account(Current.account) unless Current.account.kanban_badges.exists?
    badges = Current.account.kanban_badges.ordered
    render json: { payload: badges.map { |b| serialize(b) } }
  end

  def create
    badge = Current.account.kanban_badges.create!(badge_params)
    render json: { payload: serialize(badge) }, status: :created
  end

  def update
    @badge.update!(badge_params)
    render json: { payload: serialize(@badge) }
  end

  def destroy
    @badge.destroy!
    head :ok
  end

  def seed
    Current.account.kanban_badges.destroy_all
    KanbanBadge::DEFAULT_BADGES.each { |attrs| Current.account.kanban_badges.create!(attrs) }
    badges = Current.account.kanban_badges.ordered
    render json: { payload: badges.map { |b| serialize(b) } }
  end

  private

  def require_admin!
    return if Current.account_user.administrator?

    render json: { error: 'Forbidden' }, status: :forbidden
  end

  def fetch_badge
    @badge = Current.account.kanban_badges.find(params[:id])
  end

  def badge_params
    params.permit(:name, :description, :icon, :color, :condition_type, :condition_value, :active, :position)
  end

  def serialize(badge)
    {
      id: badge.id,
      name: badge.name,
      description: badge.description,
      icon: badge.icon,
      color: badge.color,
      condition_type: badge.condition_type,
      condition_value: badge.condition_value.to_f,
      active: badge.active,
      position: badge.position,
    }
  end
end
