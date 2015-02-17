class AddStringOnAccessTokenToDropbox < ActiveRecord::Migration
  def change
    change_column :dropboxes, :access_token, :string
  end
end
