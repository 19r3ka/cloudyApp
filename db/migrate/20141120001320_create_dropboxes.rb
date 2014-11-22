class CreateDropboxes < ActiveRecord::Migration
  def change
    create_table :dropboxes do |t|
	  t.text :access_token
      t.timestamps
    end
  end
end
