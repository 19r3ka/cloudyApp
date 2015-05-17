class DashboardController < ApplicationController
  layout 'dashboard'
  
  before_action :logged_in_user
  
  def index
    unless current_user.cloud_accounts.blank?
      redirect_to user_cloud_accounts_url(current_user)
    end
  end
  
  # Before filters
  
  # Confirms a logged-in user
  def logged_in_user
    unless logged_in?
      store_location
      flash[:danger] = "Please log in."
      redirect_to login_url
    end
  end
end
