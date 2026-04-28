class Api::V1::Accounts::Kanban::ItemsController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline, only: [:index, :show, :create, :update, :destroy, :move, :won, :lost, :reopen, :transfer]
  before_action :fetch_item, only: [:show, :update, :destroy, :move, :won, :lost, :reopen, :transfer]

  def index
    @items = pipeline_items.ordered
    @items = @items.for_stage(params[:stage_id]) if params[:stage_id].present?
    @items = @items.assigned_to(params[:assignee_id]) if params[:assignee_id].present?
    @items = @items.with_source(params[:source]) if params[:source].present?
    @items = @items.with_temperature(params[:temperature]) if params[:temperature].present?
    @items = @items.where('LOWER(title) LIKE ? OR contact_phone LIKE ?',
                          "%#{params[:search].downcase}%", "%#{params[:search]}%") if params[:search].present?
    @items = @items.where('created_at >= ?', params[:created_from]) if params[:created_from].present?
    @items = @items.where('created_at <= ?', params[:created_to]) if params[:created_to].present?
    @items = @items.where('expected_close_date >= ?', params[:close_date_from]) if params[:close_date_from].present?
    @items = @items.where('expected_close_date <= ?', params[:close_date_to]) if params[:close_date_to].present?
    @items = @items.where('value >= ?', params[:value_min]) if params[:value_min].present?
    @items = @items.where('value <= ?', params[:value_max]) if params[:value_max].present?
    @items = @items.where(lost_reason_id: params[:lost_reason_id]) if params[:lost_reason_id].present?
    if params[:status].present?
      @items = case params[:status]
               when 'won' then @items.won
               when 'lost' then @items.lost
               when 'open' then @items.open
               else @items
               end
    end
  end

  def show; end

  def create
    @item = pipeline_items.new(item_params)
    @item.save!
  end

  def transfer
    target_pipeline = Current.account.kanban_pipelines.find(params.require(:target_pipeline_id))
    target_stage = target_pipeline.kanban_stages.find(params.require(:stage_id))

    prev_pipeline_name = @pipeline.name
    prev_stage_name    = @item.stage.name

    prev_stage_id = @item.stage_id
    @item.update!(pipeline: target_pipeline, stage: target_stage, position: 0)

    log_activity(
      'moved',
      from_pipeline: @pipeline.id, to_pipeline: target_pipeline.id,
      from_pipeline_name: prev_pipeline_name, to_pipeline_name: target_pipeline.name,
      from_stage_name: prev_stage_name, to_stage_name: target_stage.name,
      description: "#{prev_pipeline_name}/#{prev_stage_name} → #{target_pipeline.name}/#{target_stage.name}"
    )
    Kanban::CancelAutomationsService.new(@item, prev_stage_id).perform
    Kanban::AutomationSchedulerService.new(@item, target_stage).perform
  end

  def update
    prev = @item.slice(:stage_id, :assignee_id, :value, :temperature, :score, :source, :conversation_id, :contact_phone, :contact_id)

    @item.update!(item_params)

    if @item.stage_id != prev['stage_id']
      auto_update_won_lost(@item.stage)
      from_stage = @pipeline.kanban_stages.find_by(id: prev['stage_id'])
      to_stage   = @item.stage
      log_activity('moved',
                   from_stage: prev['stage_id'], to_stage: @item.stage_id,
                   from_stage_name: from_stage&.name, to_stage_name: to_stage&.name,
                   description: "#{from_stage&.name} → #{to_stage&.name}")
      Kanban::CancelAutomationsService.new(@item, prev['stage_id']).perform
      Kanban::AutomationSchedulerService.new(@item, to_stage).perform
    end
    if @item.assignee_id != prev['assignee_id']
      assignee = @item.assignee
      log_activity('assigned', assignee_id: @item.assignee_id,
                               assignee_name: assignee&.name,
                               description: assignee ? "Atribuído a #{assignee.name}" : 'Responsável removido')
    end
    if @item.value.to_f != prev['value'].to_f
      log_activity('value_changed', from: prev['value'], to: @item.value,
                                    description: "R$ #{prev['value']} → R$ #{@item.value}")
    end
    if @item.temperature != prev['temperature']
      log_activity('temperature_changed', from: prev['temperature'], to: @item.temperature,
                                          description: "#{prev['temperature']} → #{@item.temperature}")
    end
    if @item.score.to_i != prev['score'].to_i
      log_activity('score_changed', from: prev['score'], to: @item.score,
                                    description: "Score #{prev['score']} → #{@item.score}")
    end
    if @item.source != prev['source']
      log_activity('source_changed', from: prev['source'], to: @item.source,
                                     description: "Origem: #{prev['source']} → #{@item.source}")
    end
    if @item.conversation_id != prev['conversation_id'] && @item.conversation_id.present?
      log_activity('conversation_linked', conversation_id: @item.conversation_id,
                                          description: "Conversa ##{@item.conversation_id} vinculada")
    end
    if @item.contact_phone != prev['contact_phone'] && @item.contact_phone.present?
      log_activity('phone_changed', phone: @item.contact_phone,
                                    description: "Telefone: #{@item.contact_phone}")
    end
    if @item.contact_id != prev['contact_id'] && @item.contact_id.present?
      contact = @item.contact
      log_activity('contact_linked', contact_id: @item.contact_id,
                                     description: "Contato vinculado: #{contact&.name}")
    end
  end

  def destroy
    @item.destroy!
    head :ok
  end

  def move
    prev_stage_id = @item.stage_id
    stage = @pipeline.kanban_stages.find(params.require(:stage_id))
    @item.update!(stage: stage, position: params[:position] || @item.position)
    if prev_stage_id != stage.id
      auto_update_won_lost(stage)
      from_stage = @pipeline.kanban_stages.find_by(id: prev_stage_id)
      log_activity('moved',
                   from_stage: prev_stage_id, to_stage: stage.id,
                   from_stage_name: from_stage&.name, to_stage_name: stage.name,
                   description: "#{from_stage&.name} → #{stage.name}")
      Kanban::CancelAutomationsService.new(@item, prev_stage_id).perform
      Kanban::AutomationSchedulerService.new(@item, stage).perform
    end
  end

  def won
    already_won   = @item.won_at.present?
    won_stage     = @pipeline.kanban_stages.find_by(is_won: true)
    prev_stage_id = @item.stage_id

    attrs = { won_at: Time.current, lost_at: nil }
    attrs[:stage_id] = won_stage.id if won_stage && @item.stage_id != won_stage.id

    @item.update!(attrs)
    log_activity('won', description: '🏆 Lead marcado como Ganho') unless already_won
    if won_stage && prev_stage_id != won_stage.id
      from_stage = @pipeline.kanban_stages.find_by(id: prev_stage_id)
      log_activity('moved', from_stage: prev_stage_id, to_stage: won_stage.id,
                            from_stage_name: from_stage&.name, to_stage_name: won_stage.name,
                            description: "#{from_stage&.name} → #{won_stage.name}")
      Kanban::CancelAutomationsService.new(@item, prev_stage_id).perform
      Kanban::AutomationSchedulerService.new(@item, won_stage).perform
    end

    auto_resolve_conversation if @pipeline.settings['auto_resolve_conversation']
  end

  def lost
    already_lost  = @item.lost_at.present?
    lost_stage    = @pipeline.kanban_stages.find_by(is_lost: true)
    prev_stage_id = @item.stage_id

    reason_id   = params[:lost_reason_id].presence
    reason_name = reason_id ? Current.account.kanban_lost_reasons.find_by(id: reason_id)&.name : nil

    attrs = { lost_at: Time.current, won_at: nil }
    attrs[:stage_id]       = lost_stage.id if lost_stage && @item.stage_id != lost_stage.id
    attrs[:lost_reason_id] = reason_id if reason_id

    @item.update!(attrs)

    unless already_lost
      log_activity('lost',
                   lost_reason_id: reason_id,
                   lost_reason_name: reason_name,
                   description: "❌ Lead marcado como Perdido#{reason_name ? " — #{reason_name}" : ''}")
    end

    if lost_stage && prev_stage_id != lost_stage.id
      from_stage = @pipeline.kanban_stages.find_by(id: prev_stage_id)
      log_activity('moved', from_stage: prev_stage_id, to_stage: lost_stage.id,
                            from_stage_name: from_stage&.name, to_stage_name: lost_stage.name,
                            description: "#{from_stage&.name} → #{lost_stage.name}")
      Kanban::CancelAutomationsService.new(@item, prev_stage_id).perform
      Kanban::AutomationSchedulerService.new(@item, lost_stage).perform
    end

    auto_resolve_conversation if @pipeline.settings['auto_resolve_conversation']
  end

  def reopen
    @item.update!(won_at: nil, lost_at: nil)
    log_activity('reopened', description: 'Lead reaberto')
  end

  private

  def auto_update_won_lost(stage)
    if stage.is_won?
      @item.update_columns(won_at: Time.current, lost_at: nil)
      log_activity('won', description: '🏆 Lead marcado como Ganho')
    elsif stage.is_lost?
      @item.update_columns(lost_at: Time.current, won_at: nil)
      log_activity('lost', description: '❌ Lead marcado como Perdido')
    end
  end

  def fetch_pipeline
    @pipeline = Current.account.kanban_pipelines.find(params[:pipeline_id])
  end

  def fetch_item
    @item = pipeline_items.find(params[:id])
  end

  def pipeline_items
    Current.account.kanban_items.for_pipeline(@pipeline.id)
  end

  def item_params
    params.permit(
      :stage_id, :conversation_id, :contact_phone, :contact_id, :title, :value,
      :assignee_id, :position, :source, :temperature, :probability,
      :expected_close_date, :score, :lost_reason_id,
      :cpf, :gender, :birth_date, :address,
      tags: []
    )
  end

  def log_activity(action_type, metadata = {})
    @item.kanban_activities.create!(
      author_id: Current.user&.id,
      action_type: action_type,
      metadata: metadata
    )
  end

  def auto_resolve_conversation
    return unless @item.conversation_id.present?

    conversation = Current.account.conversations.find_by(id: @item.conversation_id)
    conversation&.update_columns(status: 'resolved')
  end
end
