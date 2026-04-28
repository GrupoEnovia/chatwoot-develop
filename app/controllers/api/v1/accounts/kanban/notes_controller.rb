class Api::V1::Accounts::Kanban::NotesController < Api::V1::Accounts::BaseController
  before_action :fetch_item
  before_action :fetch_note, only: [:destroy]

  def index
    @notes = @item.kanban_notes.ordered
  end

  def create
    @note = @item.kanban_notes.new(content: params.require(:content), author: Current.user)
    @note.save!
  end

  def destroy
    @note.destroy!
    head :ok
  end

  private

  def fetch_item
    pipeline = Current.account.kanban_pipelines.find(params[:pipeline_id])
    @item = pipeline.kanban_items.find(params[:item_id])
  end

  def fetch_note
    @note = @item.kanban_notes.find(params[:id])
  end
end
