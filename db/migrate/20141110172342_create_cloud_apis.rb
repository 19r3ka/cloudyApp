class CreateCloudApis < ActiveRecord::Migration
  def change
    create_table :cloud_apis do |t|
      t.string :name
      t.string :auth_uri
      t.string :auth_credential
      t.string :base_uri
      t.string :file_path
      t.string :folder_path

      t.timestamps
    end
    
  end
end
