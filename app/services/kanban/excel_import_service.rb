class Kanban::ExcelImportService
  REQUIRED_COLUMNS = %w[pipeline_name stage_name title].freeze

  Result = Struct.new(:created, :updated, :errors, :total, keyword_init: true)

  def initialize(account, file, current_user_id = nil)
    @account         = account
    @file            = file
    @current_user_id = current_user_id
    @errors          = []
    @created         = 0
    @updated         = 0
  end

  def import
    spreadsheet = open_spreadsheet
    return error_result('Formato de arquivo inválido. Use .xlsx ou .csv') unless spreadsheet

    headers = spreadsheet.row(1).map { |h| h.to_s.strip.downcase.tr(' ', '_') }
    missing = REQUIRED_COLUMNS - headers
    return error_result("Colunas obrigatórias ausentes: #{missing.join(', ')}") if missing.any?

    pipelines_cache = @account.kanban_pipelines.includes(:kanban_stages).index_by { |p| p.name.downcase.strip }
    assignees_cache = @account.users.index_by { |u| u.email.downcase.strip }
    lost_reasons_cache = @account.kanban_lost_reasons.index_by { |r| r.name.downcase.strip }

    (2..spreadsheet.last_row).each do |row_num|
      row = spreadsheet.row(row_num)
      next if row.all?(&:blank?)

      row_data = Hash[headers.zip(row.map { |v| v.to_s.strip.presence })]
      process_row(row_num, row_data, pipelines_cache, assignees_cache, lost_reasons_cache)
    rescue StandardError => e
      @errors << { row: row_num, message: e.message }
    end

    Result.new(created: @created, updated: @updated, errors: @errors, total: @created + @updated)
  end

  private

  def open_spreadsheet
    return nil unless @file

    ext = File.extname(@file.original_filename).downcase
    case ext
    when '.xlsx' then Roo::Excelx.new(@file.path)
    when '.csv'  then Roo::CSV.new(@file.path, csv_options: { encoding: 'bom|utf-8' })
    else nil
    end
  rescue StandardError
    nil
  end

  def process_row(row_num, row, pipelines_cache, assignees_cache, lost_reasons_cache)
    pipeline = pipelines_cache[row['pipeline_name']&.downcase&.strip]
    unless pipeline
      @errors << { row: row_num, message: "Funil '#{row['pipeline_name']}' não encontrado" }
      return
    end

    stage = pipeline.kanban_stages.find { |s| s.name.downcase.strip == row['stage_name']&.downcase&.strip }
    unless stage
      @errors << { row: row_num, message: "Etapa '#{row['stage_name']}' não encontrada no funil '#{pipeline.name}'" }
      return
    end

    assignee_id = assignees_cache[row['assignee_email']&.downcase&.strip]&.id
    lost_reason_id = lost_reasons_cache[row['lost_reason']&.downcase&.strip]&.id

    attrs = {
      pipeline:           pipeline,
      stage:              stage,
      title:              row['title'],
      value:              parse_decimal(row['value']),
      contact_phone:      row['contact_phone'],
      cpf:                row['cpf'],
      gender:             row['gender'],
      birth_date:         parse_date(row['birth_date']),
      address:            row['address'],
      source:             row['source'],
      temperature:        row['temperature'],
      probability:        row['probability'].to_i.clamp(0, 100),
      expected_close_date: parse_date(row['expected_close_date']),
      score:              row['score'].to_i.clamp(0, 5),
      tags:               row['tags']&.split(',')&.map(&:strip)&.reject(&:blank?),
      assignee_id:        assignee_id,
      lost_reason_id:     lost_reason_id
    }.compact

    existing_id = row['id'].to_i
    item = existing_id.positive? ? @account.kanban_items.find_by(id: existing_id) : nil

    if item
      item.update!(attrs)
      @updated += 1
    else
      item = @account.kanban_items.create!(attrs)
      @account.kanban_items.find(item.id).kanban_activities.create!(
        author_id: @current_user_id,
        action_type: 'created',
        metadata: { description: 'Lead importado via planilha', source: 'excel_import' }
      )
      @created += 1
    end
  end

  def parse_decimal(val)
    return nil if val.blank?

    val.to_s.gsub(/[^\d,.]/, '').gsub(',', '.').to_d
  rescue StandardError
    nil
  end

  def parse_date(val)
    return nil if val.blank?

    Date.parse(val.to_s)
  rescue StandardError
    nil
  end

  def error_result(msg)
    Result.new(created: 0, updated: 0, errors: [{ row: 0, message: msg }], total: 0)
  end
end
