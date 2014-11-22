class DropboxController < ApplicationController
	
	def new
		authorize
	end
	
	def create
		@dropbox = Dropbox.new(@token)
		
		if @dropbox.save
			redirect_to @dropbox
		else
			#add some error handling stuff here
		end
	end
	
	def show
		query = Dropbox.last                        #    TODO: change into Dropbox.find_by(:user_id) once the user interface has been defined
		token = query.access_token					#    TODO: Find an intelligent way to add this block into a Class method
		
		@connexion = Dropbox.initialize(__method__)
		@connexion.authorization :Bearer, token
		
		
		response = @connexion.get 'account/info'            #request user account information if the access token works
		@info = JSON.parse(response.body)   #	Get the user_name
	end
	
	def update
		@dropbox = Dropbox.find_by(:user_id)
		
		if @dropbox.update_attributes(:access_token)
			redirect_to @dropbox
		else
			#add some error handling stuff here
		end
	end
	
	def destroy
		Dropbox.find_by(:user_id).destroy
		redirect_to :root
	end
	
	private
	
		def callback
			get_token
			create 				
		end
		
		def authorize
		#	csrf_token creates a random token to pass with the requests to
		#	prevent Cross Site attacks
			csrf_token = SecureRandom.base64(18).tr('+/','-_').gsub(/=*$/, '')
			session[:csrf] = csrf_token
		#	Prepare the proper url
			oauthUrl = Dropbox.build_uri(__method__) + "/oauth2/authorize"
		
		#	Prepare and send the authorization request
			params = {
				:client_id => Dropbox.APP_KEY,
				:response_type => :code,
				:redirect_uri => "#{Dropbox.APP_ROOT}/dropbox/callback",
				:state => csrf_token
			}
			query = params.map{|k,v| "#{k.to_s}=#{URI.escape(v.to_s)}"}.join '&'
			redirect_to "#{oauthUrl}?#{query}"
		end
		
		def get_token
		#	CSRF attack check
			csrf_token = session.delete(:csrf)
			if params[:state] != csrf_token
				@dropbox_message = "Possible CSRF attack!"
				redirect_to :root and return
			end
		
			@connexion = Dropbox.initialize(__method__) #initializing a faraday::connexion instance		
			
		#	request token from api
			response = @connexion.post 'oauth2/token',
						:code => params[:code],
						:redirect_uri => "#{Dropbox.APP_ROOT}/dropbox/callback",
						:grant_type => :authorization_code,
						:client_id => Dropbox.APP_KEY,
						:client_secret => Dropbox.APP_SECRET
						
			@token = JSON.parse(response.body).symbolize_keys!.extract!(:access_token) #extract token
			puts "the token to be saved is #{@token}"
		end
		
end
