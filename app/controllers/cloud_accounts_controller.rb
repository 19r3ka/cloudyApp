class CloudAccountsController < ApplicationController
  before_action :logged_user_only
  
  def new
  
  end
  
  def create
    if token = session[:new_ca_token]
      session[:new_ca_token] = nil
      if @cloud_account = CloudAccount.create_or_update(current_user, 'dropbox', token)
        flash[:success] = "Congrats. Your Dropbox account has been added to Cloudy!"
      else
        flash[:danger] = "Could not save your access you granted Cloudy"
      end
      redirect_to dashboard_url
    end
  end
  
  def index
    @cloud_accounts = current_user.cloud_accounts
    render "_cloud_explorer"
  end
  
  def show
    @cloud_account = CloudAccount.find(params[:id])
    @cloud_file = CloudFile.new(provider: @cloud_account.provider)
    @cloud_file.path = params[:file_path] if params.has_key?(:file_path)
    @cloud_file.get_metadata
    render "_cloud_explorer"
  end
  
  private
  
  def cloud_account_params
    params.permit(:provider, :access_token)
  end 
  
  # Before_filters
  	
  # Ensure the right user has access to their resources
  def logged_user_only
    unless logged_in?
	  store_location
	  flash[:danger] = "Please log in!"
	  redirect_to login_url
	end
  end 
  
  
end
