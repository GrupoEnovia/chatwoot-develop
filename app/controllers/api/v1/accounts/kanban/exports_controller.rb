class Api::V1::Accounts::Kanban::ExportsController < Api::V1::Accounts::BaseController
  def items
    send_excel(export_type: :items, filename: "kanban_leads_#{Date.today}.xlsx")
  end

  def tasks
    send_excel(export_type: :tasks, filename: "kanban_tarefas_#{Date.today}.xlsx")
  end

  def pipelines
    send_excel(export_type: :pipelines, filename: "kanban_funis_#{Date.today}.xlsx")
  end

  def full
    send_excel(export_type: :full, filename: "kanban_completo_#{Date.today}.xlsx")
  end

  private

  def send_excel(export_type:, filename:)
    service = Kanban::ExcelExportService.new(Current.account, export_params)
    package = service.public_send("export_#{export_type}")

    send_data package.to_stream.read,
              type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              filename: filename,
              disposition: 'attachment'
  end

  def export_params
    params.permit(:pipeline_id, :stage_id, :status, :created_from, :created_to)
  end
end
