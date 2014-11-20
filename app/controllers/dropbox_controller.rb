class DropboxController < ApplicationController
	require 'faraday'
	require 'json'
	
	APP_ROOT = "http://localhost:3000"
	OPENSSL_CERTS = '/usr/share/curl/ca-bundle.crt'
	
	APP_KEY = "1b6qkoy3wwiroin"
	APP_SECRET = "2q4j96j3kv7xa3h"
	
	PROTOCOL = "https://"
	BASE_URL = ".dropbox.com/1"
	
	def authorize
	#	csrf_token creates a random token to pass with the requests to
	#	prevent Cross Site attacks
		csrf_token = SecureRandom.base64(18).tr('+/','-_').gsub(/=*$/, '')
		session[:csrf] = csrf_token
	#	Prepare the proper url
		oauthUrl = "#{PROTOCOL}www#{BASE_URL}/oauth2/authorize"
	
	#	Prepare and send the authorization request
		params = {
			:client_id => APP_KEY,
			:response_type => :code,
			:redirect_uri => "#{APP_ROOT}/dropbox/callback",
			:state => csrf_token
		}
		query = params.map{|k,v| "#{k.to_s}=#{URI.escape(v.to_s)}"}.join '&'
		redirect_to "#{oauthUrl}?#{query}"
	end
	
	def callback
	#	CSRF attack check
		csrf_token = session.delete(:csrf)
		if params[:state] != csrf_token
			@dropbox_message = "Possible CSRF attack!"
			redirect_to :root and return
		end
	
	#	Prepare token url
		@url = "#{PROTOCOL}api#{BASE_URL}"
	#	initializing a faraday::connexion instance if one does not already exist
		initialize  # if @connexion.nil?
		
		
	#	request token from api
		response = @connexion.post 'oauth2/token',
					:code => params[:code],
					:redirect_uri => "#{APP_ROOT}/dropbox/callback",
					:grant_type => :authorization_code,
					:client_id => APP_KEY,
					:client_secret => APP_SECRET
					
	#	Extract the token
	#	Add the token in the authentification header
		token = JSON.parse(response.body)["access_token"]
		@connexion.authorization :Bearer, token
		
	#	request user account information if the access token works
		response = @connexion.get 'account/info'
					
	#	Get the user_name
		@info = JSON.parse(response.body)["display_name"]
					
	end
	
	private

=begin	
	def build_uri
		method = caller_locations(1,1)[0].label
		case method
	#		when 
	#			prefix = "api-content"
			when 'callback'
				prefix = "api"
			else
				prefix = "www"
		end
		url = PROTOCOL << prefix << BASE_URL
	end
=end
	
	def initialize
		@connexion = Faraday::Connection.new(@url, :ssl => {
			:ca_file => OPENSSL_CERTS}) do |faraday|
				faraday.request  :url_encoded             			# form-encode POST params
				faraday.response :logger                  			# log requests to STDOUT
				faraday.adapter  Faraday.default_adapter
			end
	end 
	
end
