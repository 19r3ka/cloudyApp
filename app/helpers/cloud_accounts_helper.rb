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
    space = {
      :available => 0,
      :used      => 0
    }
    cloud_accounts.each do |cloud_account|
      result = cloud_account.get_account_info
      space[:available] += result[0]
      space[:used]      += result[1]
    end

    space
  end

end
