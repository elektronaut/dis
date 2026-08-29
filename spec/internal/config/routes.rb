# encoding: utf-8

Rails.application.routes.draw do
  resources :images, only: [:show] do
    get :download, on: :member
    get :cached, on: :member
  end
end
