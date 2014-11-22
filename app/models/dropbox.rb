class Dropbox < ActiveRecord::Base
	
	require 'faraday'
	require 'json'
	
	class_attribute :APP_ROOT, :OPENSSL_CERTS, :APP_KEY, :APP_SECRET
	attr_reader :APP_ROOT, :OPENSSL_CERTS, :APP_KEY, :APP_SECRET
	
	self.APP_ROOT = "http://localhost:3000"
	self.OPENSSL_CERTS = '/usr/share/curl/ca-bundle.crt'
	
	self.APP_KEY = "1b6qkoy3wwiroin"
	self.APP_SECRET = "2q4j96j3kv7xa3h"
	
	PROTOCOL = "https://"
	BASE_URL = ".dropbox.com/1"
	
	validates :access_token, presence: true
	
	def self.build_uri(uri)
		case uri
			when :authorize
				prefix = "www"
			when :get_token, :show
				prefix = "api"
			else
				prefix = "api-content"
		end
		url = PROTOCOL + prefix + BASE_URL
	end
	
	def self.initialize(for_method)
		Faraday::Connection.new(Dropbox.build_uri(for_method), :ssl => {
			:ca_file => Dropbox.OPENSSL_CERTS}) do |faraday|
			faraday.request  :url_encoded             			# form-encode POST params
			faraday.response :logger                  			# log requests to STDOUT
			faraday.adapter  Faraday.default_adapter
		end
	end
	
	def self.handle_api_response(code)
		case code
			when "401"
						# Bad or expired token
			when "403"
						# Bad OAuth request
			when "404"
						# Wrong path for file or folder
			when "405"
						# Request method not handled at the endpoint
			when "429"
						# App is making too many requests
			when "503"
						# Retry as soon as possible
			when "507"
						# User exceeded their data storage
			else
				        # Everything is awesome
		end
	end
	
end


