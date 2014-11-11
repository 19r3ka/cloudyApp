class CloudApisController < ApplicationController
# this class takes care of CRUD operations on cloud storage service apis

	def index
		@cloud_apis = CloudApi.all
	end
	
	def show
		@cloud_api = CloudApi.find(params[:id])
	end
	
	def new
		@cloud_api = CloudApi.new
	end
	
	def create
		@cloud_api = CloudApi.new(cloud_api_params)
		if @cloud_api.save
			redirect_to @cloud_api
		else
			render 'new'
		end
	end
	
	def edit
		@cloud_api = CloudApi.find(params[:id])
	end
	
	def update
		@cloud_api = CloudApi.find(params[:id])
		if @cloud_api.update(params[:cloud_api].permit(:name, :auth_uri, :auth_credential, :base_uri, :file_path, :folder_path))
			redirect_to @cloud_api
		else
			render 'edit'
		end
	end
	
	def destroy
		CloudApi.find(params[:id]).destroy
		redirect_to cloud_apis_path
	end
	
	
	private
		def cloud_api_params
			params.require(:cloud_api).permit(:name, :auth_uri, :auth_credential, :base_uri, :file_path, :folder_path)
		end
end
