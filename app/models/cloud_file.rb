class CloudFile
  include ActiveModel::Model
  
  attr_accessor :size, :path, :content, :last_modified, :mime_type, :hash, :is_dir, 
                :has_thumb, :files, :provider, :cloud_account_id
                
  def initialize(provider, cloud_account_id, path="/")
    @provider = provider
    @cloud_account_id = cloud_account_id
    @path = path
    @mime_type = ""
  end
  
  # Query the selected local account or distant API for file metadata
  # Returns false if unable to get metadata
  def get_metadata
    # Get the metadata from the API server if not found locally
    metadata = cloud_account.get_metadata(@path) || self.cloud_api.get_metadata(self)
    if metadata
	  self.set_metadata(metadata)
	  if self.is_dir
	    self.files = metadata[:contents].map do |file|
		  file.symbolize_keys!
		  child_file = CloudFile.new(provider, cloud_account_id, file[:path])
		  child_file.set_metadata(file)
		  child_file
	    end
	  end
    else
      false
    end
  end
  
  # Returns a thumbnail to the file
  def thumbnail
    if self.has_thumb
    #  self.cloud_api.get_thumb(self)
    get_media
    else
      "default_file_icons/#{filetype}-icon.png"
    end
  end
  
  # Returns a link directly to a file
  def get_media
    if media = self.cloud_api.get_media(self)
      link = media[:url]
    end
    link = "default_file_icons/#{filetype}-icon.png" unless !link.nil? &&
                                                link.match(/^http(s?)/)
    link
  end
  
  # Sends file to associated cloud account
  # Returns the metadata to the file
  def upload
    unless self.content.nil?
      metadata = self.cloud_api.upload(self)
      self.set_metadata(metadata)
    else
      false
    end
  end
  
  # Download this file from the corresponding cloud account.
  def download
    self.cloud_api.download(self)
  end
  
  # Remove this file from the corresponding cloud account
  def delete
    self.cloud_api.delete(self)
  end
  
  # Moves the current cloud file to selected 'to_path'
  def move(to_path)
    self.cloud_api.move(@path, to_path)
  end
  
  # Copy the current cloud file to selected 'to_path'
  def copy(to_path)
    self.cloud_api.copy(@path, to_path)
  end
  
  def create_folder(to_path)
    self.cloud_api.create_folder(File.join(self.dir_path, to_path))
  end
  
  # Fills a cloud file with metadata
  def set_metadata(metadata)
    unless metadata.nil?
      @size          = metadata[:size]
      @path          = metadata[:path]
      @last_modified = metadata[:modified]
      @hash          = metadata[:hash]
      @is_dir        = metadata[:is_dir]
      @has_thumb     = metadata[:thumb_exists]
      @mime_type     = metadata[:mime_type] if self.is_dir == false
    end
  end
  
  # Returns a boolean if file is embeddable
  def is_embeddable?
    self.filetype.match(/^(audio|image|video)$/)
  end
  
  # Returns associated cloud_account to file
  def cloud_account
    CloudAccount.find(self.cloud_account_id) 
  end
  
  # Instantiate the csp API associated with the file's cloud account
  def cloud_api
    self.provider.camelize.constantize.new(access_token: self.cloud_account.access_token)
  end
  
  # Returns an array containing the main actions on files
  def file_actions
    actions = {
      rename: "pencil",
      download: "download",
      copy: "transfer",
      move: "move"} 
  end
  
  # Returns the appropriate name to the cloud_file
  def name
    if self.path == '/'
      self.provider
    else
      File.basename(self.path)
    end
  end
  
  # Returns the folder name of hte current cloud_file
  def dir_path
    self.get_metadata if self.is_dir.blank?
    self.is_dir ? self.path : File.dirname(self.path)
  end
  
  # Returns the path to the containing folder
  def parent
    File.dirname(self.path)
  end
  
  def children
    self.get_metadata if self.files.nil? && self.is_dir.nil?
    if self.is_dir
      self.files
    else
      false
    end
  end
  
  def siblings
    CloudFile.new(provider, cloud_account.id, parent).children
  end
  
  # Returns the main category of mimetype (audio, image, text, video, app)
  def filetype
    if is_dir || @mime_type.blank?
      "folder"
    else
      @mime_type.split("/")[0]
    end
  end
  
  # Sends the metadata search to cache
  def CloudFile.set_cache(cloud_file)
    if cloud_file.is_a? Array
      path  = 'all'
      files = cloud_file
    else
      path  = cloud_file.path  
      files = cloud_file.files  
    end
    
    Rails.cache.fetch("#{path}", expires_in: 2.hours) do
      files
    end
    
    files
  end
  
  # Retrieves a previous metadata search from cache
  def CloudFile.get_cache(path)
    Rails.cache.fetch("#{path}") unless path.nil?
  end
end
