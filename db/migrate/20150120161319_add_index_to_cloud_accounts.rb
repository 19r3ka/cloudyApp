class AddIndexToCloudAccounts < ActiveRecord::Migration
  def change
    add_index :cloud_accounts, ["user_id", "provider"], unique: true
  end
end
