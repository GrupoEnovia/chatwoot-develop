class Api::V1::Accounts::Kanban::ImportsController < Api::V1::Accounts::BaseController
  def items
    file = params[:file]
    return render json: { error: 'Arquivo não enviado' }, status: :unprocessable_entity unless file

    result = Kanban::ExcelImportService.new(Current.account, file, Current.user&.id).import

    render json: {
      payload: {
        created: result.created,
        updated: result.updated,
        total:   result.total,
        errors:  result.errors
      }
    }, status: result.errors.any? && result.total.zero? ? :unprocessable_entity : :ok
  end

  def template
    service  = Kanban::ExcelExportService.new(Current.account)
    package  = Axlsx::Package.new
    style    = package.workbook.styles.add_style(bg_color: '4F46E5', fg_color: 'FFFFFF', b: true, sz: 11)
    package.workbook.add_worksheet(name: 'Leads') do |sheet|
      sheet.add_row Kanban::ExcelExportService::ITEM_HEADERS.map { |h| h }, style: style
      sheet.add_row ['', 'Meu Funil', 'Etapa 1', 'Exemplo Lead', '5000', 'open',
                     'agent@email.com', '+5511999999999', '000.000.000-00', 'male',
                     '01/01/1990', 'Rua Exemplo, 123', 'whatsapp', 'hot', '80',
                     '31/12/2026', '5', 'tag1, tag2', '', '', '', '', '']
    end

    send_data package.to_stream.read,
              type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              filename: 'template_importacao_kanban.xlsx',
              disposition: 'attachment'
  end
end
