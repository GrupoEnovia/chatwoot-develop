class FixStopOnReplyDefault < ActiveRecord::Migration[7.1]
  def up
    change_column_default :kanban_automations, :stop_on_reply, from: true, to: false
    execute "UPDATE kanban_automations SET stop_on_reply = false WHERE stop_on_reply = true"
  end

  def down
    change_column_default :kanban_automations, :stop_on_reply, from: false, to: true
  end
end
