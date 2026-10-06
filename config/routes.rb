Rails.application.routes.draw do
  root "pages#home"
  get "chi-sono", to: "pages#about", as: :about

  resources :articles do
    # Route "member": agisce su UN articolo (richiede l'id) → notify_friend_article_path(article)
    member do
      post :notify_friend
    end
    # Risorsa annidata: i commenti non esistono senza un articolo.
    # Delle 7 azioni REST ce ne servono 3: `new` (carica il form via Ajax), `create` ed `destroy`.
    # I commenti si leggono dalla pagina dell'articolo, e non si modificano.
    resources :comments, only: [:new, :create, :destroy]
  end

  # Registrazione e modifica dei propri dati (nel libro: `resources :users` completo).
  resources :users, only: [:new, :create, :edit, :update] do
    # Cambia l'indirizzo segreto per le bozze (se l'hai condiviso per sbaglio).
    member { post :regenerate_draft_token }
  end

  # `resource` (singolare): non esiste un "elenco di sessioni", se ne crea o se ne distrugge una.
  resource :session, only: [:new, :create, :destroy]
  get "/login", to: "sessions#new", as: "login"
  # Il libro usa `get "/logout"`; qui è DELETE, perché una GET non deve mai modificare lo stato.
  delete "/logout", to: "sessions#destroy", as: "logout"
end
