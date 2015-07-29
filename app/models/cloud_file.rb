class CloudFile
  include ActiveModel::Model

  TMP_FOLDER = Rails.root.join "public/images/tmpfiles"

  attr_accessor :id, :size, :path, :content, :last_modified, :mime_type, :hash, :is_dir,
                :has_thumb, :files, :provider, :cloud_account_id, :parent, :thumb

  def initialize(provider, cloud_account_id, path="/")
    @provider = provider
    @cloud_account_id = cloud_account_id
    @path = path
    @mime_type = ""
  end

  # Query the selected local account or distant API for file metadata
  # Returns false if unable to get metadata
  def get_metadata
    # Get the metadata from the API server
    if metadata = cloud_api.get_metadata(self)
	    self.set_metadata(metadata)
	    if self.is_dir
	      @files = metadata[:contents].map do |file|
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
    if filetype == "image"
      if @thumb.nil?
        if raw_data = self.cloud_api.get_thumb(self)
          base = File.basename(name, ".*")
          ext  = @provider == "box" ? ".png" : File.extname(name)
          temp = Tempfile.new([base, ext],TMP_FOLDER, encoding: Encoding::ASCII_8BIT)
          temp.write(raw_data)
          temp.close
          @thumb = File.join(File.basename(TMP_FOLDER), File.basename(temp.path))
        end
      end
      Logger.new(STDOUT).debug "thumbnail is #{@thumb}"
      @thumb
    else
      "default_file_icons/#{filetype}-icon.png"
    end
  end

  # Returns a link directly to a file
  def get_media
    if media = self.cloud_api.get_media(self)
      link = media
    end
    link = "default_file_icons/#{filetype}-icon.png" unless !link.nil? && # Take this part out as soon as
                                                link.match(/^http(s?)/)   # thumbnail is working
    link
  end

  # Sends file to associated cloud account
  # Returns the metadata to the file
  def upload
    unless self.content.nil? #content attribute refers to raw_data to be uploaded
      metadata = self.cloud_api.upload(self)
      self.set_metadata(metadata)
    else
      false
    end
  end


  def rename
    cloud_api.rename(self, new_name)
  end

  # Download this file from the corresponding cloud account.
  def download
    cloud_api.download(self)
  end

  # Remove this file from the corresponding cloud account
  def delete
    self.cloud_api.delete(self)
  end

  # Moves the current cloud file to selected 'to_path'
  def move(to_path)
    self.cloud_api.move(self, to_path)
  end

  # Copy the current cloud file to selected 'to_path'
  def copy(to_path)
    self.cloud_api.copy(self, to_path)
  end

  # Change the name of current cloud file to 'new_name'
  def rename(new_name)
    self.cloud_api.rename(self, new_name)
  end

  def create_folder(to_path)
    self.cloud_api.create_folder(identifier, to_path)
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
      @mime_type     = metadata[:mime_type] if @is_dir == false
      @id            = metadata[:id]
      @parent        = metadata[:parent]
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
    @provider.camelize.constantize.new(access_token: cloud_account.access_token,
                                      refresh_token: cloud_account.refresh_token)
  end

  # Returns an array containing the main actions on files
  def file_actions
    actions = {
      rename:   "pencil",
      download: "download",
      copy:     "transfer",
      move:     "move"
    }
  end

  # Returns the appropriate name to the cloud_file
  def name
    if self.path == '/'
      self.provider
    else
      File.basename(self.path)
    end
  end

  # Returns the folder name of the current cloud_file
  def dir_path
    self.get_metadata if @is_dir.blank?
    self.is_dir ? @path : File.dirname(@path)
  end

  # Returns the path to the containing folder
  def parent
    @parent = File.dirname(@path) if @provider == "dropbox"
    @parent
  end

  def children
    self.get_metadata if @files.nil? || @is_dir.nil?
    if @is_dir
      @files
    else
      false
    end
  end

  def siblings
    file = CloudFile.new(provider, cloud_account.id)
    if @provider == "dropbox"
      file.path = parent
    else
      file.id   = parent
    end
    file.children
  end

  # Returns the main category of mimetype (audio, image, text, video, app)
  def filetype
    if is_dir || @mime_type.blank?
      "folder"
    else
      @mime_type.split("/")[0]
    end
  end

  #Returns the proper request query params for retrieving file
  def query_params
    case @provider
      when "box"
        {isd:  @is_dir, fid: @id}
      when "dropbox"
        {file_path: @path}
      else
    end
  end

  #Returns the attribute needed by the remote API for identifying file
  def identifier
    case @provider
    when "box"
      @id
    when "dropbox"
      @path
    else
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
