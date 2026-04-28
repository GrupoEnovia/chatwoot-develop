class CreateAiAgentSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_agent_schedules do |t|
      t.references :ai_agent, null: false, foreign_key: true, index: { unique: true }
      t.string  :google_calendar_id
      t.text    :google_refresh_token_encrypted
      t.integer :slot_duration_minutes,    default: 60,  null: false
      t.integer :max_days_in_advance,      default: 30,  null: false
      t.integer :max_concurrent_bookings,  default: 1,   null: false
      t.integer :min_notice_minutes,       default: 60,  null: false
      t.string  :default_subject
      t.jsonb   :weekly_windows, default: {}, null: false
      t.timestamps
    end
  end
end
