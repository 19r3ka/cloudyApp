class Box < ActiveRecord::Base
  OAUTH_URL    = "https://app.box.com/api/oauth2/authorize"
  OTOKEN_URL   = "https://app.box.com/api/oauth2/token"
  CALLBACK_URL = "http://localhost:3000/box/get_token"
  BASE_URL     = "https://api.box.com/2.0"
  UPLOAD_URL   = "https://upload.box.com/api/2.0"

  attr_accessor :access_token, :refresh_token

  # Get the account information from Dropbox
  # Returns array used space / available space
  def get_account_info
    c        = Box.client(BASE_URL)
    sign_connexion(c)
    response = c.get "users/me"
    res      = Box.format_response(response)
    [res[:space_used], res[:space_amount]]
  end

  # Get the file information from Box
  # Returns JSON formatted used/available space
  def get_metadata(cloud_file)
    connexion = Box.client(BASE_URL)
    sign_connexion(connexion)
    if cloud_file.is_dir.nil? || cloud_file.is_dir == "true"
      cloud_file.is_dir = true
    elsif cloud_file.is_dir == "false"
      cloud_file.is_dir = false
    end
    resource = cloud_file.is_dir ? "folders" : "files"
    id = cloud_file.id || '0'

    response = connexion.get "#{resource}/#{id}"
    response = Box.format_metadata(response)

    tree_cache(response)
  end

  def create_folder(parent, name)
    payload = {
      name: name,
      parent: {id: parent}
    }

    c = Box.client(BASE_URL)
    sign_connexion(c)
    response = c.post do |req|
      req.url "folders"
      req.body = payload.to_json
    end

    Box.format_metadata(response)
  end

  # Get the thumbnail to a specific file
  def get_thumb(cloud_file)
    id = cloud_file.id
    c = Box.client(BASE_URL)
    sign_connexion(c)

    response = c.get do |req|
      req.url "files/#{id}/thumbnail.png"
      req.params["min_width"] = 256
    end

    response.body
  end

  # Get the media associated with a specific file
  def get_media(cloud_file)
    res = get_metadata(cloud_file)
    res[:media]
  end

  # Download file from Box
  # Returns nothing
  def download(cloud_file)
    c = Box.client(BASE_URL)
    sign_connexion(c)

    response = c.get "files/#{cloud_file.id}/content"

    response.body
  end

  # Send a file up to Box
  # Returns the metadata to the uploaded file
  def upload(cloud_file)
    attributes = {name: cloud_file.name, parent: {id: cloud_file.parent}}.to_json
    payload = {
      attributes: attributes,
      file: Faraday::UploadIO.new(cloud_file.content.tempfile, cloud_file.content.content_type)
    }
    c = Box.client(UPLOAD_URL)
    #c.use FaradayMiddleware::EncodeJson
    sign_connexion(c)
    response = c.post do |req|
      req.url "files/content"
      req.body = payload
    end

    if res = Box.format_response(response)
      Box.format_metadata(res[:entries].first.symbolize_keys)
    end
  end

  def delete(cloud_file)
    c = Box.client(BASE_URL)
    sign_connexion(c)

    response = c.delete do |req|
      req.url "#{Box.file_type(cloud_file)}/#{cloud_file.id}"
      req.params["recursive"] = true
    end

    if response.status == 204
      true
    else
      false
    end
  end

  def search(query)
    c = Box.client(BASE_URL)
    sign_connexion(c)

    response = c.get do |req|
      req.url "search"
      req.params["query"] = query
    end

    Box.format_metadata(response)
  end

  def move(cloud_file, new_parent_id)
    c = Box.client(BASE_URL)
    sign_connexion(c)
    payload = {
      parent: {id: new_parent_id}
    }
    response = c.put do |req|
      req.url "#{Box.file_type(cloud_file)}/#{cloud_file.id}"
      req.body = payload.to_json
    end
    response = Box.format_metadata(response)
  end

  def rename(cloud_file, new_name) #exactly the same code as move. Needs to be dry-ed
    c = Box.client(BASE_URL)
    sign_connexion(c)
    payload = {
      name: new_name
    }
    response = c.put do |req|
      req.url "#{Box.file_type(cloud_file)}/#{cloud_file.id}"
      req.body = payload.to_json
    end
    response = Box.format_metadata(response)
  end

  def copy(cloud_file, destination)
    c = Box.client(BASE_URL)
    sign_connexion(c)
    payload = {
      parent: {id: destination}
    }
    response = c.post do |req|
      req.url "#{Box.file_type(cloud_file)}/#{cloud_file.id}/copy"
      req.body = payload.to_json
    end
    response = Box.format_metadata(response)
  end

  # Starts the client connection to the Box API
  # Returns the Faraday connection object
  def self.client(base_url)
    connexion = Faraday::Connection.new( base_url,
	  :ssl => {:ca_file => '/etc/ssl/certs/ca-certificates.crt'}) do |faraday|
	    faraday.request  :multipart
	    faraday.request  :url_encoded      # form-encode POST params
   	  faraday.response :logger           # log requests to STDOUT
      faraday.use      FaradayMiddleware::FollowRedirects
      faraday.adapter  Faraday.default_adapter
	  end
  end

  # Adds access_token to the header of the connexion
  def sign_connexion(connexion)
    connexion.authorization("Bearer", @access_token)
  end

  # Get id from the path from the filetree
  # Return id or false
  def get_id_for(cloud_file)
    path = cloud_file.path
    tree = Filetree.new("box")
    node = tree.find(path)
    id   = node.content["id"]
  end

  # Queries the Box API for the access_token
  # Returns the access token within a JSON format
  def self.get_token(oauth2_code)
    connexion = client(OTOKEN_URL)
    response  = connexion.post "",
	    code:           oauth2_code,
	    redirect_uri:   CALLBACK_URL,
	    grant_type:     :authorization_code,
	    client_id:      ENV['BOX_KEY'],
	    client_secret:  ENV['BOX_SECRET']

	  format_response(response)
  end

  # Refresh access token using the refresh_token
  # Returns new access_token and refresh_token
  def self.refresh_access
    connexion = client(OTOKEN_URL)
    Logger.new(STDOUT).debug("the refresh token is #{@refresh_token}")
    response       = connexion.post "",
      refresh_token:  @refresh_token,
      grant_type:     :refresh_token,
	    client_id:      ENV['BOX_KEY'],
	    client_secret:  ENV['BOX_SECRET']

    res = format_response(response)
    CloudAccount.create_or_update(current_user, "box", res[:access_token], res[:refresh_token])
  end

  # Check the status code of the http response
  # return reponse body parsed or an exception
  def self.handle_response(response)
    status = response.status
    case status
      when 200, 201
        result = parse_response(response)
      when 302

      when 401
      raise HttpErrors::AuthError.new(status, response.body)
      else
      raise HttpErrors::CloudError.new(status, response.body)
    end
  end

  # Handle the http response
  # Returns the parsed response or false
  def self.format_response(response)
    if response.is_a? Faraday::Response
      begin
        attempt = 0
        response = handle_response(response)
      rescue HttpErrors::AuthError => e
        Rails.logger.error "#{e.http_status}, #{e.error_message}"
        Box.refresh_access
        attempt += 1
        retry if attempt <= 1
        nil if attempt > 2
      rescue HttpErrors::CloudError => e
        Rails.logger.error "#{e.http_status}, #{e.error_message}"
      end
    end
    if response.is_a? Array
      response.map {|item| format_response(item)}
    else
      response.symbolize_keys!
    end
  end

  # Takes the response body
  # Returns it parsed
  def self.parse_response(response)
    JSON.parse(response.body)
  end

  # Format the Box response
  # Returns JSON acceptable for cloud_file metadata
  def self.format_metadata(metadata)
    metadata = format_response(metadata)
    Logger.new(STDOUT).debug("response in format_metadata is #{metadata.inspect}")
    path = File.join(metadata[:path_collection]["entries"].map{ |branch|
      branch["name"] == "All Files" ? '' : branch["name"]
      }, metadata[:name])
    path = '/' if metadata[:name] == 'All Files'
    result = {
      id:            metadata[:id],
      size:          metadata[:size],
      path:          path.blank? ? '/' : path,
      last_modified: metadata[:modified_at],
      is_dir:        metadata[:type] == "folder" ? true : false
    }
    result[:parent] = metadata[:parent]["id"] if metadata[:parent]
    result[:media]  = metadata[:shared_link]["download_url"] if metadata[:shared_link]
    result[:contents] = metadata[:item_collection]["entries"].map{ |file|
      child = {
        id:     file["id"],
        is_dir: file["type"] == "folder" ? true : false,
        path:   File.join(path, file["name"]),
      }
      child[:mime_type] = get_mimetype_from(file["name"]) unless child[:is_dir]
      child
    } if metadata[:item_collection]
    result[:mime_type] = get_mimetype_from(metadata[:name]) unless result[:is_dir]
    result
  end

  # Identifies the resource type of the current cloud file
  # Returns 'files' or 'folders' depending on the file type
  def self.file_type(cloud_file)
    return "folders" if cloud_file.is_dir == true || cloud_file.is_dir =~ (/^(true|yes|1)$/i)
    return "files" if cloud_file.is_dir == false || cloud_file.is_dir =~ (/^(false|no|0)$/i)
  end

  # Queries the API for changes since last cursor
  #	Returns the newest entries [path, metadata]
  def get_delta(cursor="", path="")
    c        = Box.client(BASE_URL)
    sign_connexion(c)
    q_params = { stream_type: "changes" }
    q_params[:stream_position] = cursor unless cursor.blank?

    res      = c.get "events", q_params
    changes  = Box.format_response(res)

    entries = changes[:entries].map { |change|
      metadata = Box.format_metadata(change["source"])
      if change["event_type"] == "ITEM_TRASH"
        [metadata[:path], nil]
      else
        [metadata[:path], metadata]
      end
    }

    delta = {
      entries: entries,
      cursor:  changes[:next_stream_position]
    }
  end

  # Queries the API to retrieve the latest cursor
  # Returns the cursor
  def get_latest_cursor(path="")
    c   = Box.client(BASE_URL)
    sign_connexion(c)
    res = c.get "events"
    res = Box.format_response(res)
    filetree = Filetree.new('box')
    filetree.latest_cursor = res[:next_stream_position]
  end

  def metadata_to_delta(metadata)
    entries = []
    if metadata.has_key?(:contents)
      entries = metadata[:contents].map { |child|
        metadata_to_delta(child).flatten!
      }
      metadata = metadata.reject {|k,v| k == :contents }
    end
    entries << [metadata[:path], metadata.stringify_keys] if metadata[:path] != '/'
    entries
  end


  def tree_cache(metadata)
    entries = metadata_to_delta(metadata)
    filetree = Filetree.new('box')
    entries.each{|entry| filetree.update(entry)}
    filetree.save
    metadata
  end

  def self.get_mimetype_from(name)
    mime_types = {
      audio: %w(mid midi kar rmi mp4a mpga mp2* mp3 m2a m3a oga ogg spx s3m sil uva uvva eol dra dts dtshd lvp pya weba aac flac mka wax wma rmp wav),
      image: %w(bmp cgm gif jpeg jpg jpe psd svg svgz tif tiff webp ico pic png),
      text:  %w(appcache ics ifb css csv html htm txt text conf log rtx vcard vcf),
      video: %w(3gp 3g2 mp4 mp4v mpg4 mpeg mpg mpe m1v m2v ogv mov m4u webm f4v flv m4v mkv vob wm wmv avi movie)
    }
    x = File.extname(name)
    x.slice!(0)
    mime_types.each { |type, ext|
      if ext.include?(x.downcase)
        return "#{type}/#{x}"
      end
    }
    "application/#{x}"
  end
end
