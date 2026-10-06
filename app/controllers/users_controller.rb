class UsersController < ApplicationController
  before_action :authenticate, only: [:edit, :update]
  before_action :set_user, only: [:edit, :update]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to login_path, notice: "Account creato: ora puoi accedere."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to root_path, notice: "Dati aggiornati."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Ognuno modifica solo se stesso: l'id nell'URL viene ignorato.
  # (Ricarico il record per non mostrare nella navbar un'email non ancora salvata.)
  def set_user
    @user = User.find(current_user.id)
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
