# == Schema Information
#
# Table name: kanban_badges
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  description     :text
#  icon            :string           default("🏅")
#  color           :string
#  condition_type  :string           not null
#  condition_value :decimal(15, 2)   default(0.0)
#  active          :boolean          default(true)
#  position        :integer          default(0)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#
BADGE_CONDITION_TYPES = %w[won_gte value_gte conversion_rate_gte max_deal_gte goal_pct_gte rank_eq].freeze

class KanbanBadge < ApplicationRecord
  belongs_to :account

  validates :name, presence: true
  validates :condition_type, inclusion: { in: BADGE_CONDITION_TYPES }
  validates :condition_value, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  DEFAULT_BADGES = [
    { name: 'Primeira Venda', description: 'Fechou ao menos 1 negócio', icon: '🎯', condition_type: 'won_gte', condition_value: 1, position: 0,
      color: 'bg-emerald-50 border-emerald-200 text-emerald-700 dark:bg-emerald-900/20 dark:border-emerald-700' },
    { name: 'Cinco em Campo', description: '5 ou mais negócios fechados', icon: '🔥', condition_type: 'won_gte', condition_value: 5, position: 1,
      color: 'bg-orange-50 border-orange-200 text-orange-700 dark:bg-orange-900/20 dark:border-orange-700' },
    { name: 'Máquina de Vendas', description: '10 ou mais negócios fechados', icon: '🏭', condition_type: 'won_gte', condition_value: 10, position: 2,
      color: 'bg-red-50 border-red-200 text-red-700 dark:bg-red-900/20 dark:border-red-700' },
    { name: 'Conversor', description: 'Taxa de conversão acima de 70%', icon: '⚡', condition_type: 'conversion_rate_gte', condition_value: 70, position: 3,
      color: 'bg-yellow-50 border-yellow-200 text-yellow-700 dark:bg-yellow-900/20 dark:border-yellow-700' },
    { name: 'Grande Negócio', description: 'Fechou deal acima de R$ 10.000', icon: '💎', condition_type: 'max_deal_gte', condition_value: 10_000, position: 4,
      color: 'bg-blue-50 border-blue-200 text-blue-700 dark:bg-blue-900/20 dark:border-blue-700' },
    { name: 'Meta Batida', description: 'Atingiu 100% da meta individual', icon: '🏆', condition_type: 'goal_pct_gte', condition_value: 100, position: 5,
      color: 'bg-violet-50 border-violet-200 text-violet-700 dark:bg-violet-900/20 dark:border-violet-700' },
    { name: 'Líder do Período', description: 'Maior pontuação do período', icon: '👑', condition_type: 'rank_eq', condition_value: 0, position: 6,
      color: 'bg-amber-50 border-amber-200 text-amber-700 dark:bg-amber-900/20 dark:border-amber-700' },
    { name: 'R$ 50K+ Club', description: 'R$ 50.000 ou mais em faturamento', icon: '💰', condition_type: 'value_gte', condition_value: 50_000, position: 7,
      color: 'bg-green-50 border-green-200 text-green-700 dark:bg-green-900/20 dark:border-green-700' },
  ].freeze

  def self.seed_for_account(account)
    return if account.kanban_badges.exists?

    DEFAULT_BADGES.each { |attrs| account.kanban_badges.create!(attrs) }
  end
end
