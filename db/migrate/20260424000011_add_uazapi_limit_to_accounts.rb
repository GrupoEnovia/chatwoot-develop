class AddUazapiLimitToAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :uazapi_instance_limit, :integer
  end
end
