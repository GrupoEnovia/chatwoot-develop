class AddPersonalFieldsToKanbanItems < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_items, :cpf, :string
    add_column :kanban_items, :gender, :string
    add_column :kanban_items, :birth_date, :date
    add_column :kanban_items, :address, :text
  end
end
