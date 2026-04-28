class Kanban::ExcelExportService
  ITEM_HEADERS = [
    'ID', 'Pipeline', 'Etapa', 'Título', 'Valor (R$)', 'Status',
    'Responsável', 'Telefone', 'CPF', 'Gênero', 'Data de Nascimento', 'Endereço',
    'Origem', 'Temperatura', 'Probabilidade (%)', 'Previsão de Fechamento',
    'Score', 'Tags', 'Motivo de Perda', 'Contato (ID)', 'Conversa (ID)',
    'Criado em', 'Atualizado em'
  ].freeze

  TASK_HEADERS = [
    'ID', 'Lead (ID)', 'Lead (Título)', 'Pipeline', 'Etapa',
    'Título', 'Descrição', 'Responsável', 'Prioridade',
    'Data Início', 'Data Limite', 'Concluída em', 'Recorrente',
    'Criado em'
  ].freeze

  PIPELINE_HEADERS = ['ID', 'Nome', 'Descrição', 'Ativo', 'Padrão', 'Posição', 'Criado em'].freeze
  STAGE_HEADERS    = ['ID', 'Pipeline', 'Nome', 'Posição', 'Cor', 'Probabilidade (%)', 'Etapa de Ganho', 'Etapa de Perda', 'Criado em'].freeze

  PRIORITY_LABELS = { 0 => 'Baixa', 1 => 'Média', 2 => 'Alta' }.freeze

  def initialize(account, params = {})
    @account = account
    @params  = params
  end

  def export_items
    items = scoped_items
    build_workbook do |wb|
      add_items_sheet(wb, items)
    end
  end

  def export_tasks
    items = scoped_items
    build_workbook do |wb|
      add_tasks_sheet(wb, items)
    end
  end

  def export_pipelines
    build_workbook do |wb|
      add_pipelines_sheet(wb)
      add_stages_sheet(wb)
    end
  end

  def export_full
    items = scoped_items
    build_workbook do |wb|
      add_items_sheet(wb, items)
      add_tasks_sheet(wb, items)
      add_pipelines_sheet(wb)
      add_stages_sheet(wb)
    end
  end

  private

  def scoped_items
    scope = @account.kanban_items.includes(:pipeline, :stage, :assignee, :lost_reason)
    scope = scope.for_pipeline(@params[:pipeline_id]) if @params[:pipeline_id].present?
    scope = scope.for_stage(@params[:stage_id])       if @params[:stage_id].present?
    scope = scope.where('created_at >= ?', @params[:created_from]) if @params[:created_from].present?
    scope = scope.where('created_at <= ?', @params[:created_to])   if @params[:created_to].present?
    if @params[:status].present?
      scope = case @params[:status]
              when 'won'  then scope.won
              when 'lost' then scope.lost
              when 'open' then scope.open
              else scope
              end
    end
    scope.ordered
  end

  def build_workbook
    package = Axlsx::Package.new
    package.workbook.styles.fonts.first.name = 'Calibri'
    yield package.workbook
    package
  end

  def header_style(wb)
    wb.styles.add_style(
      bg_color: '4F46E5',
      fg_color: 'FFFFFF',
      b: true,
      sz: 11,
      alignment: { horizontal: :center, wrap_text: true }
    )
  end

  def add_items_sheet(wb, items)
    style = header_style(wb)
    wb.add_worksheet(name: 'Leads') do |sheet|
      sheet.add_row ITEM_HEADERS, style: style
      items.each do |item|
        sheet.add_row [
          item.id,
          item.pipeline&.name,
          item.stage&.name,
          item.title,
          item.value&.to_f,
          item.status,
          item.assignee&.name,
          item.contact_phone,
          item.cpf,
          item.gender,
          item.birth_date&.strftime('%d/%m/%Y'),
          item.address,
          item.source,
          item.temperature,
          item.probability,
          item.expected_close_date&.strftime('%d/%m/%Y'),
          item.score,
          item.tags&.join(', '),
          item.lost_reason&.name,
          item.contact_id,
          item.conversation_id,
          item.created_at.strftime('%d/%m/%Y %H:%M'),
          item.updated_at.strftime('%d/%m/%Y %H:%M')
        ]
      end
      sheet.column_widths 8, 20, 20, 30, 14, 10, 20, 18, 16, 12, 18, 30, 14, 12, 16, 20, 8, 20, 20, 10, 12, 18, 18
    end
  end

  def add_tasks_sheet(wb, items)
    style = header_style(wb)
    wb.add_worksheet(name: 'Tarefas') do |sheet|
      sheet.add_row TASK_HEADERS, style: style
      items.each do |item|
        item.kanban_tasks.includes(:assignee).each do |task|
          sheet.add_row [
            task.id,
            item.id,
            item.title,
            item.pipeline&.name,
            item.stage&.name,
            task.title,
            task.description,
            task.assignee&.name,
            PRIORITY_LABELS[task.priority] || task.priority,
            task.start_date&.strftime('%d/%m/%Y'),
            task.due_date&.strftime('%d/%m/%Y'),
            task.completed_at&.strftime('%d/%m/%Y %H:%M'),
            task.is_recurring ? 'Sim' : 'Não',
            task.created_at.strftime('%d/%m/%Y %H:%M')
          ]
        end
      end
    end
  end

  def add_pipelines_sheet(wb)
    style = header_style(wb)
    wb.add_worksheet(name: 'Funis') do |sheet|
      sheet.add_row PIPELINE_HEADERS, style: style
      @account.kanban_pipelines.ordered.each do |p|
        sheet.add_row [p.id, p.name, p.description, p.is_active ? 'Sim' : 'Não', p.is_default ? 'Sim' : 'Não', p.position, p.created_at.strftime('%d/%m/%Y')]
      end
    end
  end

  def add_stages_sheet(wb)
    style = header_style(wb)
    wb.add_worksheet(name: 'Etapas') do |sheet|
      sheet.add_row STAGE_HEADERS, style: style
      @account.kanban_pipelines.includes(:kanban_stages).each do |pipeline|
        pipeline.kanban_stages.ordered.each do |stage|
          sheet.add_row [
            stage.id, pipeline.name, stage.name, stage.position, stage.color,
            stage.probability, stage.is_won ? 'Sim' : 'Não', stage.is_lost ? 'Sim' : 'Não',
            stage.created_at.strftime('%d/%m/%Y')
          ]
        end
      end
    end
  end
end
