class CloudApi < ActiveRecord::Base
	validates :name, :auth_uri, :auth_credential, :base_uri, :file_path, :folder_path, presence: true
end
