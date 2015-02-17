class AddUserIdToDropboxes < ActiveRecord::Migration
  def change
    add_reference :dropboxes, :user, index: true
  end
end
