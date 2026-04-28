class CreateChannelUazapi < ActiveRecord::Migration[7.1]
  def change
    create_table :channel_uazapi do |t|
      t.string  :uazapi_instance_name, null: false
      t.string  :uazapi_instance_token
      t.string  :phone_number
      t.string  :identifier
      t.string  :connection_status, default: 'pending'
      t.timestamps
    end

    add_index :channel_uazapi, :uazapi_instance_name, unique: true
    add_index :channel_uazapi, :identifier, unique: true
  end
end
