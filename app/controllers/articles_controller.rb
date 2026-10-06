class ArticlesController < ApplicationController
  # Chiunque può leggere; per scrivere, modificare o eliminare bisogna aver fatto il login.
  before_action :authenticate, except: [:index, :show]
  before_action :set_article, only: [:show]

  # GET /articles or /articles.json
  def index
    @articles = Article.latest_first.includes(:categories)
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

  private
    # Solo per `show`: le altre azioni cercano l'articolo tra quelli dell'utente loggato.
    def set_article
      @article = Article.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    # `category_ids: []` = un array di id (le checkbox delle categorie).
    def article_params
      params.require(:article).permit(:title, :location, :excerpt, :body, :published_at, category_ids: [])
    end
end
