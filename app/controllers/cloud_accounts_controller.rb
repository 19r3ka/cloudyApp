class CloudAccountsController < ApplicationController
  layout "dashboard"
  before_action :logged_user_only
  
  def new
  
  end
  
  def create
    if token = session[:new_ca_token]
      session[:new_ca_token] = nil
      if @cloud_account = CloudAccount.create_or_update(current_user, 'dropbox', token)
        flash[:success] = "Congrats. Your Dropbox account has been added to Cloudy!"
      else
        flash[:danger] = "Could not save the access you granted to Cloudy"
      end
      redirect_to dashboard_url
    end
  end
  
  def index
    @cloud_files = current_user.cloud_accounts.map{ |cloud_account|
      file = CloudFile.new(cloud_account.provider, cloud_account.id)
      file.get_metadata
      file.children
    }.flatten!
=begin  
    @cloud_files = []
    current_user.cloud_accounts.each do |cloud_account|
      file = CloudFile.new(cloud_account.provider, cloud_account.id)
	  file.get_metadata
      @cloud_files += file.files
    end
=end
    render "dashboard/index"
  end
  
  def show
    @cloud_account ||= CloudAccount.find(params[:id])
    @cloud_file = CloudFile.new(@cloud_account.provider, @cloud_account.id)
    @cloud_file.path = params[:file_path] if params.has_key?(:file_path)
    @cloud_file.get_metadata
    
    if @cloud_file.is_dir
      @cloud_files = @cloud_file.children
    else
      @cloud_files = @cloud_file.siblings
    end
   
    render "dashboard/index"
  end
  
  def download
    if params[:file_path]
      @cloud_account = CloudAccount.find(params[:id])
      @cloud_file = CloudFile.new(@cloud_account.provider,
                                  @cloud_account.id,
                                  path: params[:file_path])
      @cloud_file.get_metadata
      
      send_data(@cloud_file.download, type: @cloud_file.mime_type,
                                      filename: @cloud_file.name)
    else
      flash[:danger] = "Invalid path to the file to download!"
      redirect_to :back
    end
  end
  
  def upload
    if request.post?
      name = params[:cloud_file][:content].original_filename 
      path = params[:cloud_file][:folder_path]
      uploaded_file = params[:cloud_file][:content]
      
      @cloud_account = CloudAccount.find(params[:cloud_file][:cloud_account_id])
      @cloud_file = CloudFile.new(@cloud_account.provider, @cloud_account.id)
	  @cloud_file.content = uploaded_file
      
      if params[:cloud_file][:current_cloud_account_id] == @cloud_account.id.to_s
        @cloud_file.path = File.join(path, name)
      else
        @cloud_file.path = "/" << name
      end
      
      if @cloud_file.upload
        flash[:success] = "Your file #{name} has been successfully uploaded!"
        redirect_to user_cloud_account_url(current_user, @cloud_file.cloud_account, file_path: @cloud_file.path) and return
      else
        flash.now[:danger] = "Your file #{name} could not be uploaded!"
      end
    elsif request.get?
      path = params[:file_path].nil? ? "/" : params[:file_path] 
      if params[:id]
        @cloud_account   = CloudAccount.find(params[:id])
        provider         = @cloud_account.provider
        cloud_account_id = @cloud_account.id
      end
      @upload_file = @cloud_file = CloudFile.new(provider, cloud_account_id, path)                        
      @form_action = :upload
      @cloud_files = CloudFile.get_cache(session[:last_query]) if session[:last_query]
      
    else
      # Nothing else should be supported
    end
     
    render 'dashboard/index'
  end
  
  def copy
    if request.get?
      @cloud_account ||= CloudAccount.find(params[:id])
	  @cloud_file = CloudFile.new(@cloud_account.provider, @cloud_account.id)
      @cloud_file.path = params[:file_path]
      session[:copy_file] = File.join(@cloud_file.cloud_account_id.to_s, @cloud_file.path)
      
      redirect_to :back and return
    elsif request.post?
      @cloud_account ||= CloudAccount.find(params[:id])
      @cloud_file      = CloudFile.new( @cloud_account.provider, @cloud_account.id)
      @cloud_file.path = params[:file_path]
      
      to_path          = File.join(params[:destination], File.basename(@cloud_file.path))
      message = {
		  success: "Your file has been successfully copied!",
		  failure: "Something went awefully wrong!"
		}
      
      if metadata = @cloud_file.copy(to_path)
        @cloud_file.set_metadata(metadata)
        flash[:success] = message[:success]
        session[:copy_file] = nil
        redirect_to user_cloud_account_url(current_user, @cloud_file.cloud_account, file_path: @cloud_file.path) and return
      else
        flash.now[:danger] = message[:failure]
      end
    end
  end
  
  def search
    unless request.post?
      redirect_to :back, danger: "what were you trying to do?" and return
    else
      unless params[:search].has_key?(:fp) && params[:search][:fp]
        path = "/"
      else
        path = params[:search][:fp]
      end
      query = params[:search][:query]
      @cloud_account = CloudAccount.find(params[:search][:cloud_account_id])
      if result = @cloud_account.search(query)
        if result.empty?
          flash[:danger] = "Your file '#{query}' was not found!"
          redirect_to :back and return
        else       
        @cloud_files = []
        result.each {|metadata| 
          cloud_file = CloudFile.new(@cloud_account.provider, @cloud_account.id)
          cloud_file.set_metadata(metadata)
          @cloud_files << cloud_file
          flash.now[:success] = "#{result.size} #{'result'.pluralize(result.size)} for '#{query}'"
        }
        end
      else
        flash[:danger] = "Sorry, something went officially wrong!"
        redirect_to :back and return
      end 
    end
    
    render 'dashboard/index'
  end
  
  def rename
    if request.get?
      if params[:file_path]
        @cloud_account ||= CloudAccount.find(params[:id])
        @cloud_file = CloudFile.new(@cloud_account.provider, @cloud_account.id)
        @cloud_file.path = params[:file_path]
        @cloud_file.get_metadata
      else
        flash[:danger] = "Sorry, what file were you trying to rename?"
        redirect_to :back and return
      end
      
      @form_action = :rename
      @cloud_files ||= CloudFile.get_cache(session[:last_query]) if session[:last_query]
    else
      flash[:danger] = "Sorry, I did not get what you were trying to do!"
      redirect_to :back and return
    end
    
    render 'dashboard/index'
  end
  
  def move
    if request.post?
      cloud_account_id = params[:id] || params[:cloud_file][:caid]
      rename = true if params[:cloud_file] and params[:cloud_file][:fops] == "rename"
      @cloud_account = CloudAccount.find(cloud_account_id)
      @cloud_file   = CloudFile.new( @cloud_account.provider, @cloud_account.id )
      
      if rename
        @cloud_file.path = params[:cloud_file][:path]
        to_path          = File.join(File.dirname(params[:cloud_file][:path]),
                              params[:cloud_file][:name])
        
        message = {
          success: "Your file has been successfully renamed!",
          failure: "It seems something went awefully wrong!"
        }
      else    
		@cloud_file.path = params[:file_path]
		to_path          = File.join(params[:destination], File.basename(@cloud_file.path))
		
		message = {
		  success: "Your file has been successfully moved!",
		  failure: "Something went awefully wrong!"
		}
      end
      
      if metadata = @cloud_file.move(to_path)
        @cloud_file.set_metadata(metadata)
        flash[:success] = message[:success]
        session[:move_file] = nil
        redirect_to user_cloud_account_url(current_user, @cloud_file.cloud_account, file_path: @cloud_file.path) and return
      else
        flash.now[:danger] = message[:failure]
      end
    elsif request.get?
      @cloud_account ||= CloudAccount.find(params[:id])
	  @cloud_file = CloudFile.new(@cloud_account.provider, @cloud_account.id)
      @cloud_file.path = params[:file_path]
      session[:move_file] = File.join(@cloud_file.cloud_account_id.to_s, @cloud_file.path)
      
      redirect_to :back and return
    end
    
    render 'dashboard/index'
  end
  
  def delete
    @cloud_account ||= CloudAccount.find(params[:id])
    @cloud_file = CloudFile.new(@cloud_account.provider, @cloud_account.id)
    @cloud_file.path = params[:file_path]
    name = File.basename(@cloud_file.path)
    provider = @cloud_file.provider.capitalize
    
    if @cloud_file.delete
      flash[:success] = "Your file #{name} has been removed from #{provider}"
      redirect_to user_cloud_account_url(current_user, @cloud_file.cloud_account, file_path: @cloud_file.parent) and return
    else
      flash[:danger] = "Snaps! We could not delete the file as requested"
      redirect_to :back
    end
    
  end
  
  def create_folder
    if request.get?
      @cloud_account ||= CloudAccount.find(params[:id])
      @cloud_file = CloudFile.new(@cloud_account.provider, @cloud_account.id)
      @cloud_file.path = params[:file_path] if params.has_key?(:file_path)
      
      @cloud_file.get_metadata
    
      @form_action = :new_folder
    elsif request.post?
      @cloud_account = CloudAccount.find(params[:cloud_file][:caid])
      @cloud_file    = CloudFile.new(@cloud_account.provider, @cloud_account.id, params[:cloud_file][:path])
      foldername = params[:cloud_file][:name]
      
      if metadata = @cloud_file.create_folder(foldername)
        @cloud_file.set_metadata(metadata)
        flash[:success] = "Folder successfully created!"
        redirect_to user_cloud_account_url(current_user, @cloud_file.cloud_account, file_path: @cloud_file.path) and return
      else
        flash[:danger]  = "Snaps, there was a problem trying to create your folder"
        redirect_to :back and return
      end  
    else
      flash[:danger] = "What exactly were you trying to do?"
      redirect_to :back and return
    end
    
    render 'dashboard/index'
  end
  
  def cancel
    session[:move_file] = session[:copy_file] = nil
    redirect_to :back
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
