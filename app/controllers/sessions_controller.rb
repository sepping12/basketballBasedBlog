class SessionsController < ApplicationController
  # `new` non serve: basta il template sessions/new.html.erb, Rails lo renderizza da solo.

  def create
    if (user = User.authenticate(params[:email], params[:password]))
      destinazione = session[:return_to]
      reset_session                       # nuova sessione al login: evita la "session fixation"
      session[:user_id] = user.id
      redirect_to(destinazione || root_path, notice: "Accesso effettuato.")
    else
      # flash.now: il messaggio vale solo per questa risposta (non c'è un redirect).
      flash.now[:alert] = "Email o password non corretti."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session                         # azzera tutti i dati della sessione
    redirect_to root_path, notice: "Sei uscito."
  end
end
