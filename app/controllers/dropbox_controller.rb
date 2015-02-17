class DropboxController < ApplicationController
	layout "dashboard"
	include DropboxHelper
	before_action :logged_user_only 
  
	def new
	  authorize
	end
	
	def get_token
	# CSRF attack check
	  csrf_token = session.delete(:csrf)
	    if params[:state] != csrf_token
	      flash[:danger] = "Possible CSRF attack!"
	      redirect_to :root and return
	    end
		
	  connexion = Dropbox.start(__method__) #initializing a faraday::connexion instance	
	
	  #	request token from api
      response = connexion.post 'oauth2/token',
								:code => params[:code],
								:redirect_uri => "http://#{request.domain}:3000/dropbox/get_token",
								:grant_type => :authorization_code,
								:client_id => ENV['DROPBOX_KEY'],
								:client_secret => ENV['DROPBOX_SECRET']
	  							
      if session[:new_ca_token] = res[:access_token] 
        redirect_to url_for(controller: 'cloud_accounts', action: 'create')
      else
		flash[:danger] = "Couldn't get authorization from Dropbox!"
		redirect_to dashboard_url
      end    
    end
  
	private
	
	# Access the OAuth endpoint to grant authorization to the app
	  def authorize
		
		csrf_token = SecureRandom.base64(18).tr('+/','-_').gsub(/=*$/, '')
		session[:csrf] = csrf_token
		
		oauthUrl = Dropbox.build_uri(__method__) + "/oauth2/authorize" #build the proper url
		
		#	Prepare and send the authorization request
		params = {
		  :client_id => APP_KEY,
		  :response_type => :code,
		  :redirect_uri => "http://#{request.domain}:3000/dropbox/get_token",
		  :state => csrf_token
		}
		query = params.map{|k,v| "#{k.to_s}=#{URI.escape(v.to_s)}"}.join '&'
		redirect_to "#{oauthUrl}?#{query}"
		
	  end

  # Before_filters
  	
  # Ensure the right user has access to their resources
  def logged_user_only
    unless logged_in?
	  store_location
	  flash[:danger] = "Pleascreatee log in!"
	  redirect_to login_url
	end
  end  
end
