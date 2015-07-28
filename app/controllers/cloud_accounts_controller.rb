class CloudAccountsController < ApplicationController
  layout "dashboard"
  before_action :logged_user_only

  def new

  end

  def create
    if raw_token = session[:new_ca_token]
      session[:new_ca_token] = nil
      cloud_provider, token, refresh = raw_token.split ','
      logger.debug "access_token before being save in #{token}"
      if @cloud_account = CloudAccount.create_or_update(current_user, cloud_provider, token, refresh)
        flash[:success] = "Congrats. Your #{cloud_provider.capitalize} account has been added to Cloudy!"
      else
        flash[:danger] = "Something went wrong trying to connect to #{cloud_provider.capitalize}"
      end
      # render plain: CloudAccount.all.inspect and return
      redirect_to dashboard_url
    end
  end

  def index
    @cloud_files = current_user.cloud_accounts.map{ |cloud_account|
      file = CloudFile.new(cloud_account.provider, cloud_account.id)
      file.get_metadata
      file.children
    }.flatten!

    render "dashboard/index"
  end

  def show
    @cloud_account   ||= CloudAccount.find(params[:id])
    @cloud_file        = CloudFile.new(@cloud_account.provider, @cloud_account.id)
    @cloud_file.path   = params[:file_path] if params.has_key?(:file_path)
    @cloud_file.id     = params[:fid] if params.has_key?(:fid)
    @cloud_file.is_dir = params[:isd] if params.has_key?(:isd)
    @cloud_file.get_metadata

    if @cloud_file.is_dir
      @cloud_files = @cloud_file.children
    else
      @cloud_files = @cloud_file.siblings
    end
    render "dashboard/index"
  end

  def download
    if params[:file_path] || params[:fid]
      @cloud_account   ||= CloudAccount.find(params[:id])
      @cloud_file        = CloudFile.new(@cloud_account.provider, @cloud_account.id)
      @cloud_file.path   = params[:file_path] if params.has_key?(:file_path)
      @cloud_file.id     = params[:fid] if params.has_key?(:fid)
      @cloud_file.is_dir = params[:isd] if params.has_key?(:isd)
      @cloud_file.get_metadata

      send_data(@cloud_file.download, type: @cloud_file.mime_type, filename: @cloud_file.name) and return
    else
      flash[:danger] = "Invalid path to the file to download!"
      redirect_to :back
    end
  end

  def upload
    if request.post?
      name = params[:cloud_file][:content].original_filename
      path = params[:cloud_file][:folder_path] if params[:cloud_file].has_key?(:folder_path)
      id   = params[:cloud_file][:folder_id] if params[:cloud_file].has_key?(:folder_id)
      uploaded_file = params[:cloud_file][:content]

      @cloud_account = CloudAccount.find(params[:cloud_file][:cloud_account_id])
      @cloud_file    = CloudFile.new(@cloud_account.provider, @cloud_account.id)
	    @cloud_file.content = uploaded_file
      @cloud_file.parent = id ? id : 0

      if params[:cloud_file][:current_cloud_account_id] == @cloud_account.id.to_s
        @cloud_file.path = File.join(path, name)
      else
        @cloud_file.path = "/" << name
      end

      #render plain: @cloud_file.inspect and return
      if metadata = @cloud_file.upload                       ####### handle the case of Box (isd / fid)
        flash[:success] = "Your file #{name} has been successfully uploaded!"
        redirect_to user_cloud_account_url(current_user, @cloud_file.cloud_account, @cloud_file.query_params) and return
      else
        flash.now[:danger] = "Your file #{name} could not be uploaded!"
      end
    elsif request.get?
      if params[:id]
        @cloud_account   = CloudAccount.find(params[:id])
        provider         = @cloud_account.provider
        cloud_account_id = @cloud_account.id
      end

      @form_action = :upload
      @upload_file = CloudFile.new(provider, cloud_account_id)
      if params[:file_path]
        @upload_file.path = params[:file_path]
      elsif params[:fid]
        @upload_file.id     = params[:fid]
        @upload_file.is_dir = params[:isd]
      else
        @upload_file.path = '/'
        @upload_file.id   = '0'
      end
      @cloud_file = @upload_file
      @cloud_file.get_metadata
      if @cloud_file.is_dir
        @cloud_files = @cloud_file.children
      else
        @cloud_files = @cloud_file.siblings
      end
    else
      # Nothing else should be supported
    end

    render "dashboard/index"
  end

  def copy
    if request.get?
      cloud_account_id = params[:id]
      @cloud_account   ||= CloudAccount.find(params[:id])
      @cloud_file        = CloudFile.new(@cloud_account.provider, @cloud_account.id)
      if params.has_key?(:file_path)
        @cloud_file.path = identifier = params[:file_path]
      elsif params.has_key?(:fid)
        @cloud_file.id   = identifier = params[:fid]
        end

      @cloud_file.is_dir = params[:isd]       if params.has_key?(:isd)
      session[:copy_file] = [@cloud_file.cloud_account_id.to_s, identifier].join(',')

      redirect_to :back and return
    elsif request.post?
      @cloud_account ||= CloudAccount.find(params[:id])
      @cloud_file      = CloudFile.new( @cloud_account.provider, @cloud_account.id)

      identifier = params[:identifier]
      if @cloud_account.provider == "dropbox"
        @cloud_file.path = File.join('/', identifier)
        to_path          = File.join(params[:destination], File.basename(identifier))
      elsif @cloud_account.provider == "box"
        @cloud_file.id = identifier
        @cloud_file.is_dir = params[:is_dir]
        to_path           = params[:destination]
      end
      message          = {
		      success: "Your file has been successfully copied!",
		      failure: "Something went awefully wrong!"
		  }

      if params[:dest_caid] != params[:id] #inter-csp move in progress
      else
        if metadata = @cloud_file.copy(to_path)
          @cloud_file.set_metadata(metadata)
          flash[:success] = message[:success]
          session[:copy_file] = nil
          redirect_to user_cloud_account_url(current_user, @cloud_file.cloud_account, @cloud_file.query_params) and return
        else
          flash[:danger] = message[:failure]
          redirect_to :back and return
        end
      end
    end
    render "dashboard/index"
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
          flash[:danger] = "'#{query.capitalize}' yielded no results!"
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
        flash[:danger] = "Sorry, something went wrong!"
        redirect_to :back and return
      end
    end

    render 'dashboard/index'
  end

  def rename
    if request.get?
      @cloud_account ||= CloudAccount.find(params[:id])
      @cloud_file = CloudFile.new(@cloud_account.provider, @cloud_account.id)

      if params[:file_path]
        @cloud_file.path = params[:file_path]
      elsif params[:fid]
        @cloud_file.id     = params[:fid]
        @cloud_file.is_dir = params[:isd]
      else
        flash[:danger] = "Sorry, what file were you trying to rename?"
        redirect_to :back and return
      end

      @cloud_file.get_metadata
      @form_action = :rename
      @cloud_files ||= @cloud_file.siblings
    elsif request.post?
      @cloud_account = CloudAccount.find(params[:cloud_file][:caid])
      @cloud_file   = CloudFile.new( @cloud_account.provider, @cloud_account.id )
      if @cloud_account.provider == "dropbox"
        @cloud_file.path = params[:cloud_file][:identifier] #identifier stores path or id depending on the csp
        new_name         = File.join(File.dirname(params[:cloud_file][:path]),
                           params[:cloud_file][:name])
      elsif @cloud_account.provider == "box"
        @cloud_file.id     = params[:cloud_file][:identifier]
        @cloud_file.is_dir = params[:cloud_file][:dir]
        new_name           = params[:cloud_file][:name]
      end

      message          = {
          success: "Your file has been successfully renamed!",
          failure: "It seems something went awefully wrong!"
      }

      if metadata = @cloud_file.rename(new_name)
        @cloud_file.set_metadata(metadata)
        flash[:success] = message[:success]
        redirect_to user_cloud_account_url(current_user, @cloud_file.cloud_account, @cloud_file.query_params) and return
      else
        flash[:failure] = message[:failure]
      end
    else
      flash[:danger] = "Sorry, I did not get what you were trying to do!"
      redirect_to :back and return
    end

    render 'dashboard/index'
  end

  def move
    if request.post?
      cloud_account_id = params[:id]
      @cloud_account = CloudAccount.find(cloud_account_id)
      @cloud_file   = CloudFile.new( @cloud_account.provider, @cloud_account.id )
      identifier = params[:identifier]

      if @cloud_account.provider == "dropbox"
        @cloud_file.path = File.join('/', identifier)
        to_path          = File.join(params[:destination], File.basename(identifier))
      elsif @cloud_account.provider == "box"
        @cloud_file.id = identifier
        @cloud_file.is_dir = params[:is_dir]
        to_path           = params[:destination]
      end

      message          = {
		      success: "Your file has been successfully moved!",
		      failure: "Something went awefully wrong!"
		  }

      if params[:dest_caid] != cloud_account_id #inter-csp move in progress
      else
        if metadata = @cloud_file.move(to_path)
          @cloud_file.set_metadata(metadata)
          flash[:success] = message[:success]
          session[:move_file] = nil
          redirect_to user_cloud_account_url(current_user, @cloud_file.cloud_account, @cloud_file.query_params) and return
        else
          flash.now[:danger] = message[:failure]
          redirect_to :back and return
        end
      end
    elsif request.get?
      @cloud_account   ||= CloudAccount.find(params[:id])
      @cloud_file        = CloudFile.new(@cloud_account.provider, @cloud_account.id)
      if params.has_key?(:file_path)
        @cloud_file.path = identifier = params[:file_path]
      elsif params.has_key?(:fid)
        @cloud_file.id   = identifier = params[:fid]
        end

      @cloud_file.is_dir = params[:isd]       if params.has_key?(:isd)
      session[:move_file] = [@cloud_file.cloud_account_id.to_s, identifier].join(',')

      redirect_to :back and return
    end

    render 'dashboard/index'
  end

  def delete
    @cloud_account   ||= CloudAccount.find(params[:id])
    @cloud_file        = CloudFile.new(@cloud_account.provider, @cloud_account.id)
    @cloud_file.path   = params[:file_path] if params.has_key?(:file_path)
    @cloud_file.id     = params[:fid] if params.has_key?(:fid)
    @cloud_file.is_dir = params[:isd] if params.has_key?(:isd)
    #name = File.basename(@cloud_file.path)
    provider = @cloud_file.provider.capitalize

    if @cloud_file.delete
      flash[:success] = "Your file has been removed from #{provider}"
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
      if @cloud_account.provider == "dropbox"
        @cloud_file.path = params[:file_path] if params.has_key?(:file_path)
      elsif @cloud_account.provider == "box"
        @cloud_file.id     = params[:fid]
        @cloud_file.is_dir = params[:is_dir]
      end

      @cloud_file.get_metadata
      @cloud_files = @cloud_file.files
      @form_action = :new_folder
    elsif request.post?
      @cloud_account = CloudAccount.find(params[:cloud_file][:caid])
      @cloud_file    = CloudFile.new(@cloud_account.provider, @cloud_account.id)
      foldername     = params[:cloud_file][:name]

      if @cloud_account.provider == "dropbox"
        @cloud_file.path   = params[:cloud_file][:identifier]
      elsif @cloud_account.provider == "box"
        @cloud_file.id     = params[:cloud_file][:identifier]
        @cloud_file.is_dir = true
      end

      if metadata = @cloud_file.create_folder(foldername)
        @cloud_file.set_metadata(metadata)
        render plain: @cloud_file.inspect and return
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
