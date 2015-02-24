class Dropbox < ActiveRecord::Base

  require 'faraday'
  require 'json'
	
  PROTOCOL = "https://"
  BASE_URL = ".dropbox.com/1"

  attr_accessor :access_token, :space_available, :space_used
  
  # Get the account information from Dropbox
  # Returns JSON formatted used/available space
  def get_account_info
    uri = {account_info_path: "account/info"}
    access_token = self.access_token
 
    if res = Dropbox.successful_request?(:account_info, access_token, uri)
      res = format_response(res)
      self.space_used = res[:quota_info]["normal"] + res[:quota_info]["shared"]
      self.space_available = res[:quota_info]["quota"] 
    else
      false
    end
  end
  
  # Get the file information from Dropbox
  # Returns JSON formatted used/available space
  def get_file_info(cloud_file)
    uri = {file_path: cloud_file.path}
    access_token = self.access_token
    
    Dropbox.successful_request?(:metadata, access_token, uri)   
  end
  
  # Download file from Dropbox
  # Returns nothing
  def get_file(cloud_file)
    uri = {file_path: cloud_file.path}
    File.open(cloud_file.name, "w") do |f|
      if res = Dropbox.successful_request?(:file, self.access_token, uri)
        f.write(res)
      end
    end
  end
  
  
  
  # Class methods
  
  # Initializes the Faraday connection to the API
  # Returns a Faraday connection instance
  def Dropbox.start(for_method, access_token = nil)
	connexion = Faraday::Connection.new(build_uri(for_method), 
	  :ssl => {:ca_file => '/etc/ssl/certs/ca-certificates.crt'}) do |faraday|
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
	  when :get_token, :account_info
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
	    suffix = "metadata/auto#{URI.escape(uri[:file_path]) if uri.has_key?(:file_path)}"
	    connexion.params['list'] = true 
		connexion.params['include_media_info'] = true
	  when :account_info
	    suffix = uri[:account_info_path]
	  when :file
	    suffix = "files/auto#{URI.escape(uri[:file_path]) if uri.has_key?(:file_path)}"
    end
    
    Dropbox.dp_get(connexion, suffix)
  end
  
  private
  
  # middleware to access the API and handle errors 
  def Dropbox.dp_get(connexion, suffix)
    response = connexion.get do |req|
      req.url suffix
    end
  end
  
  def format_response(response)
    JSON.parse(response.body).symbolize_keys!
  end
  
end


