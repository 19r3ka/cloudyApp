class BoxController < ApplicationController
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

	  oauth_code = params[:code]
	  res        = Box.get_token(oauth_code)
    logger.debug "response in get_token: #{res.inspect}"
    if res && res.has_key?(:access_token)
      session[:new_ca_token] = "#{controller_name},#{res[:access_token]},#{res[:refresh_token]}"
      redirect_to create_cloud_accounts_url
    else
	    flash[:danger] = "Couldn't get authorization from Box!"
	    redirect_to dashboard_url
    end
  end

  private

  # Access the OAuth endpoint to grant authorization to the app
  def authorize
    csrf_token = SecureRandom.base64(18).tr('+/','-_').gsub(/=*$/, '')
  	session[:csrf] = csrf_token

    #	Prepare and send the authorization request
	  params = {
      client_id:     ENV['BOX_KEY'],
	    response_type: :code,
      redirect_uri:  Box::CALLBACK_URL,
	    state:         csrf_token
	  }
	  query = params.map{|k,v| "#{k.to_s}=#{URI.escape(v.to_s)}"}.join '&'
	  redirect_to "#{Box::OAUTH_URL}?#{query}"
  end


  #Before_filters

  def logged_user_only
    unless logged_in?
	    store_location
	    flash[:danger] = "Please log in!"
	    redirect_to login_url
	  end
  end
end
