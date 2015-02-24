class CreateCloudFiles < ActiveRecord::Migration
  def change
    create_table :cloud_files do |t|

      t.timestamps
    end
  end
end
