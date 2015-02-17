module CloudAccountsHelper
  # Displays the accounts available that are not yet connected
  def show_disconnected_accounts
    supported_accounts = ['dropbox', 'google drive']
    disconnected_accounts = []
    supported_accounts.each do |account|
      unless current_user.cloud_accounts.has_value?(account)
		disconnected_accounts << account
      end
    end
    disconnected_accounts
  end
  # Fetch, aggregate, and display the cloud of current_user
  def display_cloud_info(cloud_accounts)
    account = {
      space_available: 0,
      space_used: 0
    }
    cloud_accounts.each do |cloud_account|
      cloud_account.get_account_info
      account[:space_available] += cloud_account.space_available
      account[:space_used] += cloud_account.space_used
    end
    
    account
  end
end
