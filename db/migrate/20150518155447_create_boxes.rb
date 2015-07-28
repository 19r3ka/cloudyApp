class CreateBoxes < ActiveRecord::Migration
  def change
    create_table :boxes do |t|
      t.string :access_token

      t.timestamps
    end
  end
end
