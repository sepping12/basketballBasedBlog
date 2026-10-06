class ApplicationController < ActionController::Base
  # helper_method rende questi metodi disponibili anche nelle viste.
  helper_method :current_user, :logged_in?

  private

  # L'utente loggato (o nil). In sessione si conserva solo l'id, non l'intero oggetto:
  # un oggetto in sessione diventerebbe "stantio" se l'utente cambia.
  def current_user
    return unless session[:user_id]
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end

  # Filtro: si usa con `before_action :authenticate`.
  def authenticate
    logged_in? || access_denied
  end

  def access_denied
    # Ricorda la pagina richiesta, così dopo il login si torna lì (solo percorsi interni: li decide il server).
    session[:return_to] = request.fullpath if request.get?
    redirect_to login_path, alert: "Accedi per continuare."
  end
end
