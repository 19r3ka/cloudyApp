class CloudAccount < ActiveRecord::Base
  belongs_to :user
  
  validates :access_token, :provider, presence: true
  validates :user, presence: true
  
  attr_accessor :space_available, :space_used
  
  # Populates params with a valid cloud account instance
  def CloudAccount.create_or_update(user, provider, token)
    raw_params = { provider: provider, access_token: token }
    params = ActionController::Parameters.new(raw_params)
    if @cloud_account = CloudAccount.find_by(user_id: user.id, provider: provider)
      @cloud_account.update(params.permit(:access_token))
    else
      @cloud_account = user.cloud_accounts.create(params.permit(:provider, :access_token))
    end
  end
  
  def get_account_info
    case self.provider
      when "dropbox"
        @dropbox = Dropbox.new(access_token: self.access_token)
        @dropbox.get_account_info
        
        self.space_available = @dropbox.space_available
        self.space_used = @dropbox.space_used
    end
  end
end
