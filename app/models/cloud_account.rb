class CloudAccount < ActiveRecord::Base
  belongs_to :user
  has_many   :cloud_files
  
  validates :access_token, :provider, presence: true
  validates :user, presence: true
  
  attr_accessor :space_available, :space_used, :filetree
  
  # Create or update a cloud account
  # Returns the new cloud account instance
  def CloudAccount.create_or_update(user, provider, token)
    raw_params = { provider: provider, access_token: token }
    params = ActionController::Parameters.new(raw_params)
    if @cloud_account = CloudAccount.find_by(user_id: user.id, provider: provider)
      @cloud_account.update(params.permit(:access_token))
    else
      @cloud_account = user.cloud_accounts.create(params.permit(:provider, :access_token))
    end
  end
  
  # Query the selected cloud account profile according to the cloud provider
  # Returns the space used and total available
  def get_account_info
    case self.provider
      when "dropbox"
        @dropbox ||= Dropbox.new(access_token: self.access_token)
        @dropbox.get_account_info
        
        self.space_available = @dropbox.space_available
        self.space_used = @dropbox.space_used
    end
  end
  
  # Search the associated csp API for query at the path provided
  #Returns the metadata for all results
  def search(query, *path)
    cloud_api.search(query, path)
  end
  
  def load_tree
    Filetree.new(self.provider)
  end
  
  # Load the filetree and find content at file path
  # Returns the metadata if file is not folder
  def get_metadata(file_path)
	Logger.new(STDOUT).debug "we just entered the cloud_account.get_metadata"
    self.filetree ||= load_tree
    Logger.new(STDOUT).debug "filetree in cloud_account.get_metadata is #{filetree.inspect}"
    sync
    node = self.filetree.find(file_path)
    if node.nil? || node.blank?
      return false
    else
      if node.is_folder? 
        # populate the metadata contents key with the metadata of contained files
        contents = node.content.map{|cnode|
          if cnode.is_folder? 
            cnode.content = {
              path: File.join(file_path, cnode.name),
              is_dir: true
            }
          end
          cnode.content 
        }
        
        node.content = {
          "path"     => file_path,
          "is_dir"   => true,
          "contents" => contents
        }
      end
      node.content.symbolize_keys!
    end
  end
  
  def sync
    self.filetree ||= load_tree
    
    # self.filetree.latest_cursor = cloud_api.get_latest_cursor if self.filetree.latest_cursor.nil?
    if delta = cloud_api.get_delta(self.filetree.latest_cursor)
      unless delta[:entries].empty?
        self.filetree.latest_cursor = delta[:cursor]
        self.filetree.reset if delta[:reset]
        delta[:entries].each { |entry|
          self.filetree.update(entry)
        }
        sync if delta[:has_more]
      end
    end
    Logger.new(STDOUT).debug "After sync cloud_account.filetree is #{self.filetree.inspect}"
  end
  
  private
  
  # Instantiate the csp API associated with the file's cloud account
  def cloud_api
    self.provider.camelize.constantize.new(access_token: self.access_token)
  end
  
end
