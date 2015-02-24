class CloudFile < ActiveRecord::Base

  belongs_to :cloud_account
  attr_accessor :size, :path, :last_modified, :mime_type, :is_dir, 
                :files, :provider, :cloud_account_id
  
  # Query the selected API for file metadata
  # Returns metadata in JSON format
  def get_metadata
    case self.provider
      when "dropbox"
        @dropbox ||= Dropbox.new(access_token: associated_account.access_token)
        if metadata = @dropbox.get_file_info(self)
          self.size = metadata["size"]
          self.path = metadata["path"]
          self.last_modified =  metadata["modified"]
          self.is_dir = metadata["is_dir"]
          self.mime_type = metadata["mime_type"] if self.is_dir == false
          self.files = metadata["contents"] if self.is_dir == true
        end
    end
  end
  
  def download
    case self.provider
      when "dropbox"
        @dropbox ||= Dropbox.new(access_token: associated_account.access_token)
        @dropbox.get_file(self)
    end
  end
 
 def upload
 
 end
 
 private
 
 def associated_account
   @cloud_account = current_user.cloud_accounts.where(provider: self.provider).first 
 end
end
