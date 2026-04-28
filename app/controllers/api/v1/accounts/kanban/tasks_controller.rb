class Api::V1::Accounts::Kanban::TasksController < Api::V1::Accounts::BaseController
  before_action :fetch_item
  before_action :fetch_task, only: [:update, :destroy, :complete, :reopen]

  def index
    @tasks = @item.kanban_tasks.ordered
  end

  def create
    @task = @item.kanban_tasks.new(task_params)
    @task.save!
    log_activity('task_created', title: @task.title, description: "Tarefa criada: #{@task.title}")
  end

  def update
    @task.update!(task_params)
  end

  def destroy
    @task.destroy!
    head :ok
  end

  def complete
    @task.update!(completed_at: Time.current)
    log_activity('task_completed', title: @task.title, description: "Tarefa concluída: #{@task.title}")
  end

  def reopen
    @task.update!(completed_at: nil)
    log_activity('task_created', title: @task.title, description: "Tarefa reaberta: #{@task.title}")
  end

  private

  def fetch_item
    pipeline = Current.account.kanban_pipelines.find(params[:pipeline_id])
    @item = pipeline.kanban_items.find(params[:item_id])
  end

  def fetch_task
    @task = @item.kanban_tasks.find(params[:id])
  end

  def task_params
    p = params.permit(
      :title, :description, :assignee_id, :due_date, :due_at, :priority, :completed_at,
      :start_date, :is_recurring, :recurrence_frequency, :recurrence_interval, :recurrence_end_date
    )
    p[:priority] = p[:priority].to_i if p[:priority].present?
    p[:recurrence_interval] = p[:recurrence_interval].to_i if p[:recurrence_interval].present?
    p
  end

  def log_activity(action_type, metadata = {})
    @item.kanban_activities.create!(
      author_id: Current.user&.id,
      action_type: action_type,
      metadata: metadata
    )
  end
end
