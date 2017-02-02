Maestrano::Connector::Rails::Engine.routes.draw do
  maestrano_routes

  get 'version', to: 'version#index'

  namespace :maestrano do
    match 'signout', to: 'sessions#destroy', as: 'signout', via: [:get, :post]
    post 'connec/notifications/:tenant' => 'connec#notifications'

    resources :dependancies, only: [:index]

    scope ':tenant' do
      resources :synchronizations, only: [:show, :create] do
        collection do
          put :toggle_sync
          put :update_metadata
        end
      end
    end
  end
end
