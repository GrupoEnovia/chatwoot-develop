# == Schema Information
#
# Table name: kanban_attachments
#
#  id             :bigint           not null, primary key
#  file_name      :string           not null
#  file_size      :integer
#  file_type      :string
#  url            :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  kanban_item_id :bigint           not null
#  uploaded_by_id :bigint           not null
#
# Indexes
#
#  index_kanban_attachments_on_kanban_item_id  (kanban_item_id)
#  index_kanban_attachments_on_uploaded_by_id  (uploaded_by_id)
#
class KanbanAttachment < ApplicationRecord
  belongs_to :kanban_item
  belongs_to :uploaded_by, class_name: 'User'

  validates :file_name, :url, presence: true

  scope :ordered, -> { order(created_at: :desc) }

  def image?
    file_type&.start_with?('image/')
  end

  def pdf?
    file_type == 'application/pdf'
  end

  def formatted_size
    return nil unless file_size
    if file_size < 1024
      "#{file_size} B"
    elsif file_size < 1_048_576
      "#{(file_size / 1024.0).round(1)} KB"
    else
      "#{(file_size / 1_048_576.0).round(1)} MB"
    end
  end
end
