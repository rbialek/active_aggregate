ActiveAggregate::Engine.routes.draw do
  resources :events, only: %i"new create"
end
