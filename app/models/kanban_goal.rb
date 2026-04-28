# == Schema Information
#
# Table name: kanban_goals
#
#  id           :bigint           not null, primary key
#  month        :integer          not null
#  target_value :decimal(15, 2)   default(0.0)
#  target_won   :integer          default(0)
#  year         :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  assignee_id  :bigint           not null
#
# Indexes
#
#  idx_on_account_id_assignee_id_year_month_3cf2446bc5  (account_id,assignee_id,year,month) UNIQUE
#
class KanbanGoal < ApplicationRecord
  belongs_to :account
  belongs_to :assignee, class_name: 'User'

  validates :month, inclusion: { in: 1..12 }
  validates :year, numericality: { greater_than: 2020 }
  validates :assignee_id, uniqueness: { scope: [:account_id, :year, :month] }

  scope :for_month, ->(year, month) { where(year: year, month: month) }
  scope :for_account, ->(account) { where(account: account) }
end
