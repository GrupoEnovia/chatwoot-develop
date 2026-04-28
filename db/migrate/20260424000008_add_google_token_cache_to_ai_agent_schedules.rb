class AddGoogleTokenCacheToAiAgentSchedules < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_agent_schedules, :google_access_token_encrypted, :text
    add_column :ai_agent_schedules, :google_token_expires_at, :datetime
  end
end
