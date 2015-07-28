class Dropbox < ActiveRecord::Base

  require 'faraday'
  require 'json'

  PROTOCOL = "https://"
  BASE_URL = ".dropbox.com/1"

  attr_accessor :access_token, :space_available, :space_used

  # Get the account information from Dropbox
  # Returns array used space / available space
  def get_account_info
    uri = {account_info_path: "account/info"}
    access_token = self.access_token

    if res = Dropbox.successful_request?(:account_info, access_token, uri)
      res = format_response(res)
      space_used = res[:quota_info]["normal"] + res[:quota_info]["shared"]
      space_available = res[:quota_info]["quota"]
      [space_used, space_available]
    else
      false
    end
  end

  # Get the file information from Dropbox
  # Returns JSON formatted used/available space
  def get_metadata(cloud_file)
    uri = {file_path: cloud_file.path} if cloud_file.path
    response = format_response(Dropbox.successful_request?(:metadata, access_token, uri))
    tree_cache(response)
  end

  # Get the link to a specific file on the Dropbox servers
  # Returns JSON formatted link and expiration date
  def get_media(cloud_file)
    uri = {file_path: cloud_file.path} if cloud_file.path

    media = format_response(Dropbox.successful_request?(:media, access_token, uri))
    media[:url]
  end

  # Get the thumbnail to the requested file
  # Returns ?
  def get_thumb(cloud_file)
    uri = {file_path: cloud_file.path} if cloud_file.path
    response = Dropbox.successful_request?(:thumbnail, access_token, uri)

    response.body
  end

  # Queries the API for changes since last cursor
  #	Returns the newest entries [path, metadata]
  def get_delta(cursor="", path="")
    payload = {
      include_media_info: true
    }
    payload[:cursor]      = cursor unless cursor.nil? || cursor.blank?
    payload[:path_prefix] = path unless path.blank?

    connexion  = Dropbox.start(:delta, access_token)
    response   = connexion.post do |req|
      req.url    "delta"
      req.body = payload
    end
    res = format_response(response)
    res
  end

  # Queries the API to retrieve the latest cursor
  # Returns the cursor in a hash
  def get_latest_cursor(path="")
    payload    = {
      include_media_info: true
    }
    payload[:path_prefix] = path unless path.blank?

    connexion  = Dropbox.start(:latest_cursor, access_token)
    response   = connexion.post do |req|
      req.url    "delta/latest_cursor"
      req.body = payload
    end

    res = format_response(response)
    res[:cursor]
  end

  # Download file from Dropbox
  # Returns nothing
  def download(cloud_file)
    uri = {file_path: cloud_file.path}
    response = Dropbox.successful_request?(:file, access_token, uri)

    response.body
  end

  # Upload file to Dropbox
  # Returns uploaded file metadata
  def upload(cloud_file)
    uri = {file_path: cloud_file.path}
    response = format_response(Dropbox.file_put(cloud_file.content, access_token, uri))
    tree_cache(response)
  end

  # Delete file from Dropbox
  # Returns the metadata of the deleted file
  def delete(cloud_file)

    payload = {
      root: "auto",
      path: cloud_file.path
    }

    connexion = Dropbox.start(:delete, access_token)
    response  = connexion.post do |req|
      req.url    "fileops/delete"
      req.body = payload
    end
    response = format_response(response)
    Filetree.new('dropbox').update([response[:path], nil])

  end

  # Search Dropbox for files with query in name
  # Returns results in JSON format
  def search(query, path="/")
    # TODO: Only query the API if the filetree search is unsuccessful
    url       = File.join("search/auto", path)
    payload   = { query: query}
    connexion = Dropbox.start(:search, access_token)
    response  = connexion.post do |req|
      req.url    url
      req.body = payload
    end

    format_response(response)
  end

  # Move file from one place to another
  # Returns the new metadata of the moved file
  def move(cloud_file, to_path, root="auto")
    payload = {
      root:      root,
      from_path: cloud_file.path,
      to_path:   to_path
    }

    connexion = Dropbox.start(:move, access_token)
    res  = connexion.post do |req|
      req.url "fileops/move"
      req.body = payload
    end

      response = format_response(res)
      #tree_cache(response)
  end

  # Move file from one place to another
  # Returns the new metadata of the moved file
  def copy(cloud_file, to_path, root="auto")
    payload = {
      root:      root,
      from_path: cloud_file.path,
      to_path:   to_path
    }

    connexion = Dropbox.start(:copy, access_token)
    res  = connexion.post do |req|
      req.url "fileops/copy"
      req.body = payload
    end

    response = format_response(res)
    #tree_cache(response)
  end

  # Rename item with new_name
  def rename(old_name, new_name)
    move(old_name, new_name)
  end

  # Create new folder
  # Returns the metadata of the new folder
  def create_folder(folder_path, name, root="auto")
    to_path = File.join(folder_path, name)
    payload = {
      path: to_path,
      root: root
    }

    connexion = Dropbox.start(:create_folder, access_token)
    response = connexion.post do |req|
      req.url "fileops/create_folder"
      req.body = payload
    end

    response = format_response(response)
    tree_cache(response)
  end

  def metadata_to_delta(metadata)
    entries = []
    if metadata.has_key?(:contents)
      entries = metadata[:contents].map { |child|
        metadata_to_delta(child.symbolize_keys!).flatten!
      }
      metadata = metadata.reject {|k,v| k == :contents }
    end
    entries << [metadata[:path], metadata.stringify_keys] if metadata[:path] != '/'
    entries
  end


  def tree_cache(metadata)
    entries = metadata_to_delta(metadata)
    unless entries.empty?
      filetree = Filetree.new('dropbox')
      entries.each{|entry| filetree.update(entry)}
      filetree.save
    end
    metadata
  end

  # Class methods

  # Initializes the Faraday connection to the API
  # Returns a Faraday connection instance
  def Dropbox.start(for_method, access_token = nil)
	connexion = Faraday::Connection.new(build_uri(for_method),
	  :ssl => {:ca_file => '/etc/ssl/certs/ca-certificates.crt'}) do |faraday|
	  faraday.request  :multipart
	  faraday.request  :url_encoded      # form-encode POST params
   	  faraday.response :logger           # log requests to STDOUT
      faraday.adapter  Faraday.default_adapter
	end
	connexion.authorization("Bearer", access_token) unless access_token.nil?
	connexion
  end

  # Builds the base uri of the API endpoint
  # Returns the right uri for querying the API
  def Dropbox.build_uri(uri)
	case uri
	  when :authorize
		prefix = "www"
	  when :get_token, :account_info, :metadata, :media, :delete, :move, :copy, :create_folder, :search, :delta, :latest_cursor
		prefix = "api"
	  else
		prefix = "api-content"
	end
	url = PROTOCOL + prefix + BASE_URL
  end

  # Returns the status of the request of the API
  def Dropbox.successful_request?(resource, access_token, uri={}, params={})
    connexion = Dropbox.start(resource, access_token)

    case resource
      when :metadata
	    suffix = "metadata/auto#{URI.escape(uri[:file_path]) if uri && uri.has_key?(:file_path)}"
	    connexion.params['list'] = true
		connexion.params['include_media_info'] = true
      when :media
        suffix= "media/auto#{URI.escape(uri[:file_path]) if uri && uri.has_key?(:file_path)}"
      when :thumbnail
        suffix= "thumbnails/auto#{URI.escape(uri[:file_path]) if uri && uri.has_key?(:file_path)}"
        connexion.params['size'] = 'l'
	  when :account_info
	    suffix = uri[:account_info_path]
	  when :file
	    suffix = "files/auto#{URI.escape(uri[:file_path]) if uri && uri.has_key?(:file_path)}"
    end

    Dropbox.dp_get(connexion, suffix)
  end

  def Dropbox.file_put(content, access_token, uri)
    connexion = Dropbox.start(:upload, access_token)
    suffix    = "files_put/auto#{URI.escape(uri[:file_path]) if uri && uri.has_key?(:file_path)}"

    connexion.params[:overwrite] = false
    connexion.params[:autorename] = true

    connexion.put do |req|
      req.url suffix
      req.headers['Content-Length'] = "#{content.size}"
      req.headers['Content-Type']   = content.content_type
      req.body = content.tempfile.read
    end
  end

  private

  # middleware to access the API and handle errors
  def Dropbox.dp_get(connexion, suffix)
    response = connexion.get do |req|
      req.url suffix
    end
  end

  def handle_response(response)
    status = response.status
    case status
      when 200
        parse_response(response)
      else
        raise "#{status} -> #{response.body}"
    end
  end

  def format_response(response)
    if response.is_a? Faraday::Response
      begin
        response = handle_response(response)
      rescue => e
        logger.warn "An error occured: #{e}"
        return false
      end
    end
    if response.is_a? Array
      response.map {|item| format_response(item)}
    else
      response.symbolize_keys!
    end
  end

  def parse_response(response)
    JSON.parse(response.body)
  end
end


