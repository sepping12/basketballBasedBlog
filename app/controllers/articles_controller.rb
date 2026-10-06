class ArticlesController < ApplicationController
  # Chiunque può leggere; per scrivere, modificare o eliminare bisogna aver fatto il login.
  # "Invia a un amico" è pubblico, come la lettura.
  before_action :authenticate, except: [:index, :show, :notify_friend]
  before_action :set_article, only: [:show, :notify_friend]

  # GET /articles or /articles.json
  def index
    @articles = Article.visible_to(current_user).latest_first.includes(:categories).with_rich_text_body.with_attached_cover_image
  end

  # GET /articles/1 or /articles/1.json
  def show
  end

  # GET /articles/new
  def new
    @article = Article.new
  end

  # GET /articles/1/edit
  def edit
    @article = current_user.articles.find(params[:id])   # solo i propri articoli
  end

  # POST /articles or /articles.json
  def create
    @article = current_user.articles.new(article_params)  # l'autore è sempre l'utente loggato

    respond_to do |format|
      if @article.save
        format.html { redirect_to @article, notice: "Articolo pubblicato!" }
        format.json { render :show, status: :created, location: @article }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @article.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /articles/1 or /articles/1.json
  def update
    @article = current_user.articles.find(params[:id])

    respond_to do |format|
      if @article.update(article_params)
        format.html { redirect_to @article, notice: "Modifiche salvate." }
        format.json { render :show, status: :ok, location: @article }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @article.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /articles/1 or /articles/1.json
  def destroy
    @article = current_user.articles.find(params[:id])
    @article.destroy

    respond_to do |format|
      format.html { redirect_to articles_path, status: :see_other, notice: "Articolo eliminato." }
      format.json { head :no_content }
    end
  end

  # POST /articles/1/notify_friend — "Invia a un amico": un lettore consiglia l'articolo per email.
  def notify_friend
    nome = params[:name].to_s.gsub(/[[:cntrl:]]/, " ").strip.first(60)       # niente a-capo: è usato nell'oggetto dell'email
    email = params[:email].to_s.strip

    if !@article.published?
      redirect_to @article, alert: "Si possono consigliare solo articoli pubblicati."
    elsif nome.blank? || email.length > 254 || email !~ URI::MailTo::EMAIL_REGEXP
      redirect_to article_path(@article, anchor: "invia-amico"), alert: "Scrivi il tuo nome e un indirizzo email valido."
    else
      NotifierMailer.email_friend(@article, nome, email).deliver_now
      redirect_to @article, notice: "Messaggio inviato al tuo amico."
    end
  end

  private
    # Per `show` e `notify_friend`: si vedono gli articoli pubblicati e le PROPRIE bozze (altrimenti 404).
    # Le altre azioni (modifica, elimina…) cercano l'articolo tra quelli dell'utente loggato.
    def set_article
      @article = Article.visible_to(current_user).find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    # `category_ids: []` = un array di id (le checkbox delle categorie).
    # `cover_image` = il file caricato; `remove_cover_image` = la checkbox "rimuovi l'immagine".
    def article_params
      params.require(:article).permit(:title, :cover_image, :remove_cover_image, :location, :excerpt, :body,
                                      :published_at, category_ids: [])
    end
end
