module SessionsHelper

  # Logs in the given user
  def log_in(user)
    session[:user_id] = user.id
    load_cloud_accounts
  end
  
  # Remembers a user in a persistent session
  def remember(user)
    user.remember
    cookies.permanent.signed[:user_id] = user.id
    cookies.permanent[:remember_token] = user.remember_token
  end
  
  # Forget a persistent user
  def forget(user)
    user.forget
    cookies.delete(:user_id)
    cookies.delete(:remember_token)
  end
  
  # Returns the current logged-in user
  def current_user
	if(user_id = session[:user_id])
	  @current_user ||= User.find_by(id: user_id)
	elsif(user_id = cookies.signed[:user_id])
	  user = User.find_by(id: user_id)
	  if(user && user.authenticated?(:remember, cookies[:remember_token]))
		log_in user
		@current_user = user
	  end
	end
  end
  
  # Returns true if the given user is the current user
  def current_user?(user)
    user == current_user
  end
  
  # Returns true if the user is logged in, false otherwise
  def logged_in?
    !current_user.nil?
  end
  
  # Logs current user out
  def log_out
    forget(current_user)
    unload_cloud_accounts
    @current_user = nil
    session.delete(:user_id)
  end
  
  # Redirects to stored location (or to the defaults)
  def redirect_back_or(defaults)
    redirect_to(session[:forwarding_url] || defaults)
    session.delete(:forwarding_url)
  end
  
  # Stores the URL to be accessed
  def store_location
    session[:forwarding_url] = request.url if request.get?
  end

  # Dumps current user's cloud access_tokens into session
  def load_cloud_accounts
    if logged_in?
      if cloud_accounts = current_user.CloudAccount.build
        cloud_accounts.each do |account|
          session[account.provider.to_sym] = account.access_token
        end
      end
    end
  end
  
  # nullifies access_tokens in session
  def unload_cloud_accounts
    if logged_in?
      if cloud_accounts = current_user.CloudAccount.build
        cloud_accounts.each do |account|
          session[account.provider.to_sym] = nil
        end
      end
    end
  end
end
