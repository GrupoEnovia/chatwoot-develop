class Kanban::ExecuteAutomationActionJob < ApplicationJob
  queue_as :default

  def perform(execution_id)
    execution = KanbanAutomationExecution.find_by(id: execution_id)
    return unless execution&.pending?

    Kanban::ExecuteActionService.new(execution).perform
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
