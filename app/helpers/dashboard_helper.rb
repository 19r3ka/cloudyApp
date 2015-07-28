module DashboardHelper
  def build_tag(file)
    case file.filetype
	  when "audio"
	    audio_tag(@cloud_file.get_media, controls: true, class: "col-md-12")
	  when "image"
		image_tag(@cloud_file.get_media, class: "img-responsive center-block")
	  when "video"
	  	content_tag :div, class: "embed-responsive embed-responsive-16by9" do
	  	  video_tag(@cloud_file.get_media, controls: true, autobuffer: true,
	  	                                   class: "embed-responsive-item")
	    end
	end
  end

  def build_form(action)
    case action
      when :upload
	    form = 'dashboard/upload_form'
	  when :rename
	    form = 'dashboard/rename_form'
	  when :new_folder
	    form = 'dashboard/new_folder_form'
	  when :move, :copy
	    form = 'dashboard/move_form'
	  else
	    form = 'dashboard/search_form'
	end
	render form
  end

  # Use to handle ongoing copy / move operations
  def ongoing_operation
    msg = url = ""

    if session[:move_file]
      action = "moved"
      file_branch = session[:move_file].split(',')
      cloud_account_id = file_branch.shift
      identifier = file_branch.shift
      filename   = File.basename(session[:move_file])
      url        = move_path(current_user, CloudAccount.find(cloud_account_id),
        identifier: identifier, is_dir: @cloud_file.is_dir, destination: @cloud_file.identifier,
        dest_caid: @cloud_file.cloud_account.id) if @cloud_file
    elsif session[:copy_file]
      action = "copied"
      file_branch = session[:copy_file].split(',')
      cloud_account_id = file_branch.shift
      identifier = file_branch.shift
      filename   = File.basename(session[:copy_file])
      url        = copy_path(current_user, CloudAccount.find(cloud_account_id),
        identifier: identifier, is_dir: @cloud_file.is_dir, destination: @cloud_file.identifier,
        dest_caid: @cloud_file.cloud_account.id) if @cloud_file
    end

    msg = "You have a file waiting to be #{action}"
    ops = {msg: msg, url: url}
    if session[:copy_file] || session[:move_file]
      render partial: "dashboard/ongoing_ops", locals: {action: ops}
    end
  end

  def params_for(file)
    param = {}
    case file.provider
      when "box"
        param[:fid] = file.id
        param[:isd] = file.is_dir
      when "dropbox"
        param[:file_path] = file.path
    end
    param
  end
end
