class CommentsController < ApplicationController
  before_action :load_article, except: :destroy
  before_action :authenticate, only: :destroy

  # GET /articles/5/comments/new
  # Con `link_to ..., remote: true` (Ajax) risponde new.js.erb; senza JavaScript, la pagina new.html.erb.
  def new
    @comment = Comment.new
    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    # Non uso @article.comments.new: aggiungerebbe un commento non salvato alla lista dei commenti dell'articolo.
    @comment = Comment.new(comment_params)
    @comment.article = @article

    respond_to do |format|
      if @comment.save
        format.html { redirect_to article_path(@article, anchor: "commenti"), notice: "Grazie per il commento!" }
        format.js                                   # senza blocco: Rails renderizza create.js.erb
      else
        # Nel libro: redirect con "Unable to add comment" (HTML) e un alert() (JavaScript).
        # Qui si ri-mostra il form con gli errori e il testo già scritto, in entrambi i casi.
        format.html { render "articles/show", status: :unprocessable_entity }
        format.js   { render :fail_create, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    # Solo l'autore dell'articolo può eliminare i commenti: la ricerca parte da current_user.articles.
    @article = current_user.articles.find(params[:article_id])
    @comment = @article.comments.find(params[:id])
    @comment.destroy

    respond_to do |format|
      format.html { redirect_to article_path(@article, anchor: "commenti"), notice: "Commento eliminato." }
      format.js
    end
  end

  private

  def load_article
    @article = Article.find(params[:article_id])
  end

  def comment_params
    params.require(:comment).permit(:name, :email, :body)
  end
end
