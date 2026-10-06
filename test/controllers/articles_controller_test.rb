require 'test_helper'

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @article = articles(:one)          # dell'utente one
    log_in_as users(:one)              # dal Capitolo 8 per scrivere serve il login
  end

  test "should get index" do
    get articles_url
    assert_response :success
  end

  test "should get new" do
    get new_article_url
    assert_response :success
  end

  test "should create article" do
    assert_difference('Article.count') do
      post articles_url, params: { article: { body: @article.body, excerpt: @article.excerpt, location: @article.location, published_at: @article.published_at, title: @article.title } }
    end

    assert_redirected_to article_url(Article.last)
  end

  test "should show article" do
    get article_url(@article)
    assert_response :success
  end

  test "should get edit" do
    get edit_article_url(@article)
    assert_response :success
  end

  test "should update article" do
    patch article_url(@article), params: { article: { body: @article.body, excerpt: @article.excerpt, location: @article.location, published_at: @article.published_at, title: @article.title } }
    assert_redirected_to article_url(@article)
  end

  test "should destroy article" do
    assert_difference('Article.count', -1) do
      delete article_url(@article)
    end

    assert_redirected_to articles_url
  end

  # --- Capitolo 7: il ciclo di richiesta di Action Pack -------------------------

  test "index mostra una card per ogni articolo (render @articles usa il partial _article)" do
    get articles_url
    assert_select ".card", count: Article.count
    assert_select ".card__title a", text: articles(:one).title
  end

  test "ogni azione renderizza il template con il suo nome, dentro il layout" do
    get article_url(@article)
    assert_select "h1", text: @article.title
    assert_select "nav.nav"            # navbar: arriva dal layout (application.html.erb)
    assert_select "footer.site-footer" # footer: idem
  end

  test "lo stesso URL risponde anche in JSON: l'API gratis dello scaffold" do
    get articles_url(format: :json)
    assert_response :success
    assert_equal "application/json", response.media_type
    titles = JSON.parse(response.body).map { |a| a["title"] }
    assert_includes titles, @article.title
  end

  test "create con dati validi fa redirect e imposta il messaggio flash (notice)" do
    post articles_url, params: { article: { title: "Nuovo", body: "Testo" } }
    assert_redirected_to article_url(Article.find_by!(title: "Nuovo"))
    assert_equal "Articolo pubblicato!", flash[:notice]
    follow_redirect!
    assert_select ".toast", text: "Articolo pubblicato!"
  end

  test "create con dati non validi NON fa redirect: ri-renderizza il form con gli errori" do
    assert_no_difference("Article.count") do
      post articles_url, params: { article: { title: "", body: "" } }
    end
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: "Titolo è obbligatorio"
    assert_select "#error_explanation li", text: "Testo è obbligatorio"
    assert_select ".field_with_errors"
  end

  test "un articolo inesistente solleva RecordNotFound (in produzione diventa una pagina 404)" do
    # Nell'ambiente di test Rails lascia passare l'eccezione (show_exceptions = false);
    # in produzione la trasforma in una risposta 404.
    assert_raises(ActiveRecord::RecordNotFound) { get article_url(id: 999_999) }
  end

  test "destroy fa redirect con 303 e messaggio" do
    delete article_url(@article)
    assert_response :see_other
    assert_equal "Articolo eliminato.", flash[:notice]
  end

  # --- Capitolo 8: login, proprietà, categorie, escape dell'HTML ----------------

  test "create assegna l'articolo all'utente loggato e IGNORA un user_id passato nei parametri" do
    post articles_url, params: { article: { title: "Hack", body: "x", user_id: users(:two).id } }
    assert_equal users(:one), Article.find_by!(title: "Hack").user
  end

  test "le categorie scelte nel form vengono salvate (category_ids: [])" do
    post articles_url, params: { article: { title: "Con categorie", body: "x",
                                            category_ids: ["", categories(:tattica).id, categories(:nba).id] } }
    assert_equal %w[NBA Tattica], Article.find_by!(title: "Con categorie").categories.map(&:name)
  end

  test "il form mostra le categorie come checkbox, con quelle dell'articolo già spuntate" do
    @article.categories << categories(:nba)
    get edit_article_url(@article)
    assert_select "input[type=checkbox][name='article[category_ids][]']", count: Category.count
    assert_select "input[type=checkbox][checked][value='#{categories(:nba).id}']"
    assert_select "input[type=checkbox][checked][value='#{categories(:tattica).id}']", count: 0
  end

  test "l'HTML nel testo di un articolo non viene eseguito" do
    @article.update!(body: "Ciao <script>alert('xss')</script> <b>grassetto</b>")
    get article_url(@article)
    assert_no_match(/<script>alert/, response.body)
  end

  test "l'HTML nel titolo viene mostrato come testo (escape)" do
    @article.update!(title: "<img src=x onerror=alert(1)>")
    get article_url(@article)
    assert_no_match(/<img src=x onerror/, response.body)
    assert_includes response.body, "&lt;img src=x"
  end

  test "l'autore vede Modifica ed Elimina nella pagina dell'articolo" do
    get article_url(@article)
    assert_select ".article-actions a[href='#{edit_article_path(@article)}']"
    assert_select ".article-actions a[data-method=delete]"
  end

  test "un altro utente NON li vede" do
    delete logout_path
    log_in_as users(:two)
    get article_url(@article)
    assert_select ".article-actions a[href='#{edit_article_path(@article)}']", count: 0
    assert_select ".article-actions a[data-method=delete]", count: 0
  end
end

class ArticlesAccessControlTest < ActionDispatch::IntegrationTest
  setup { @article = articles(:one) }

  test "chiunque può leggere elenco e articoli" do
    get articles_url
    assert_response :success
    get article_url(@article)
    assert_response :success
  end

  test "senza login: new, create, edit, update e destroy portano al login" do
    get new_article_url
    assert_redirected_to login_path
    assert_no_difference("Article.count") { post articles_url, params: { article: { title: "x", body: "y" } } }
    assert_redirected_to login_path
    get edit_article_url(@article)
    assert_redirected_to login_path
    patch article_url(@article), params: { article: { title: "Cambiato" } }
    assert_redirected_to login_path
    assert_no_difference("Article.count") { delete article_url(@article) }
    assert_redirected_to login_path
    assert_equal "Articolo pubblicato", @article.reload.title
  end

  test "il messaggio al login negato è un alert" do
    get new_article_url
    assert_equal "Accedi per continuare.", flash[:alert]
  end

  test "un utente non può modificare né eliminare gli articoli di un altro" do
    log_in_as users(:two)               # l'articolo one è dell'utente one
    assert_raises(ActiveRecord::RecordNotFound) { get edit_article_url(@article) }
    assert_raises(ActiveRecord::RecordNotFound) { patch article_url(@article), params: { article: { title: "Rubato" } } }
    assert_raises(ActiveRecord::RecordNotFound) { delete article_url(@article) }
    assert_equal "Articolo pubblicato", @article.reload.title
    assert Article.exists?(@article.id)
  end
end
