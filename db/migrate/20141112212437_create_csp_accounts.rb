class CreateCspAccounts < ActiveRecord::Migration
  def change
    create_table :csp_accounts do |t|
      t.string :access_token
      t.references :cloud_api, index: true

      t.timestamps
    end
  end
end
