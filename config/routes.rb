Rails.application.routes.draw do

  get 'password_resets/new'
  get 'password_resets/edit'
  
  root 'pages#home'
  
  get 'dashboard'                                        => 'dashboard#index'
  get 'dashboard/cancel'                                 => 'cloud_accounts#cancel',             as: :cancel
  
  post 'users/:user_id/cloud_accounts/search'            => 'cloud_accounts#search',        as: :search
  get 'users/:user_id/cloud_accounts/:id/download/'      => 'cloud_accounts#download',      as: :download
  get 'users/:user_id/cloud_accounts/:id/copy/'          => 'cloud_accounts#copy'
  post 'users/:user_id/cloud_accounts/:id/copy/'         => 'cloud_accounts#copy',          as: :copy
  get 'users/:user_id/cloud_accounts/:id/rename/'        => 'cloud_accounts#rename'
  get 'users/:user_id/cloud_accounts/:id/move/'          => 'cloud_accounts#move'
  post 'users/:user_id/cloud_accounts/:id/move/'         => 'cloud_accounts#move',          as: :move
  get 'users/:user_id/cloud_accounts/:id/delete/'        => 'cloud_accounts#delete'
  get 'users/:user_id/cloud_accounts/upload'             => 'cloud_accounts#upload'
  post 'users/:user_id/cloud_accounts/upload/'           => 'cloud_accounts#upload',        as: :upload
  get 'users/:user_id/cloud_accounts/:id/create_folder'  => 'cloud_accounts#create_folder'
  post 'users/:user_id/cloud_accounts/:id/create_folder' => 'cloud_accounts#create_folder', as: :new_folder
  get 'users/:user_id/cloud_accounts/:id/'               => 'cloud_accounts#show'
  
  get 'cloud_accounts' => 'cloud_accounts#index'
  
  get 'help'     => 'pages#help'
  get 'about'    => 'pages#about'
  get 'contact'  => 'pages#contact'
	
  get 'signup'            => 'users#new'
  get 'dropbox/get_token' => 'dropbox#get_token'
  get 'dropbox/new'       => 'dropbox#new'
  
  get 'cloud_accounts/create' => 'cloud_accounts#create'
  	
  get 'login'    => 'sessions#new'
  post 'login'   => 'sessions#create'
  delete 'logout'=> 'sessions#destroy'

  resources :cloud_apis
  
  resources :users do
    resources :cloud_accounts do 
      member do 
        get 'download', 'upload', 'rename', 'copy', 'move'
      end
    end
  end
	
  resource :dropbox, controller: 'dropbox' do
    member do
	  get 'get_token'
	end
  end
	
  resources :account_activations, only: [:edit]
  resources :password_resets, only: [:new, :create, :edit, :update]
  resources :dashboard, controller: 'dashboard', only: [:index]
	

	
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
