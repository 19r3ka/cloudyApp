class CreateCloudAccounts < ActiveRecord::Migration
  def change
    create_table :cloud_accounts do |t|
      t.string :provider, index: true
      t.string :access_token
      t.references :user, index: true

      t.timestamps
    end
  end
end
