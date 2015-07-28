class AddRefreshTokenToCloudAccounts < ActiveRecord::Migration
  def change
    add_column :cloud_accounts, :refresh_token, :string
  end
end
