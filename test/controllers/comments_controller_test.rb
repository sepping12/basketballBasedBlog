require 'test_helper'

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @article = articles(:one)          # pubblicato, dell'utente one
    @draft = articles(:two)            # bozza, dell'utente two
  end

  def commento(attrs = {})
    { comment: { name: "Ospite", email: "ospite@example.com", body: "Bell'articolo!" }.merge(attrs) }
  end

  test "la pagina dell'articolo mostra i commenti, ma NON il form: c'è un link che lo carica via Ajax" do
    get article_url(@article)
    assert_select "#commenti .comment", count: @article.comments.count
    assert_select "#form-commento form", count: 0
    assert_select "a#new_comment_link[data-remote=true][href='#{new_article_comment_path(@article)}']"
  end

  test "chiunque può commentare un articolo pubblicato" do
    assert_difference("@article.comments.count") do
      assert_emails(1) { post article_comments_url(@article), params: commento }
    end
    assert_redirected_to article_path(@article, anchor: "commenti")
    follow_redirect!
    assert_select ".toast", text: "Grazie per il commento!"
  end

  test "commento non valido: 422, errori e testo già scritto ancora nel form" do
    assert_no_difference("Comment.count") do
      post article_comments_url(@article), params: commento(name: "", body: "Testo che non si deve perdere", email: "")
    end
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: "Nome è obbligatorio"
    assert_select "#error_explanation li", text: "Email è obbligatorio"
    assert_select "textarea[name='comment[body]']", text: /Testo che non si deve perdere/
  end

  test "una bozza è invisibile ai visitatori: nemmeno si può commentare (404)" do
    assert_raises(ActiveRecord::RecordNotFound) { post article_comments_url(@draft), params: commento }
    assert_no_difference("Comment.count") do
      assert_raises(ActiveRecord::RecordNotFound) { post article_comments_url(@draft), params: commento }
    end
  end

  test "l'autore di una bozza la vede, ma non può commentarla (non è pubblicata)" do
    log_in_as users(:two)                      # la bozza è dell'utente two
    assert_no_difference("Comment.count") { post article_comments_url(@draft), params: commento }
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: "Articolo non è ancora pubblicato"
  end

  test "i commenti non mostrano le email ai visitatori" do
    get article_url(@article)
    assert_select ".comment__email", count: 0
    assert_no_match(/ospite@example.com/, response.body.sub(/<form.*<\/form>/m, ""))
  end

  test "l'autore dell'articolo vede l'email e il link per eliminare" do
    log_in_as users(:one)
    get article_url(@article)
    assert_select ".comment__email", text: "ospite@example.com"
    assert_select ".comment a[data-method=delete]"
  end

  test "un utente che non è l'autore non vede il link per eliminare" do
    log_in_as users(:two)
    get article_url(@article)
    assert_select ".comment a[data-method=delete]", count: 0
  end

  test "eliminare un commento richiede il login" do
    assert_no_difference("Comment.count") { delete article_comment_url(@article, comments(:one)) }
    assert_redirected_to login_path
  end

  test "solo l'autore dell'articolo può eliminare i commenti" do
    log_in_as users(:two)
    assert_raises(ActiveRecord::RecordNotFound) { delete article_comment_url(@article, comments(:one)) }
    assert Comment.exists?(comments(:one).id)
  end

  test "l'autore elimina un commento" do
    log_in_as users(:one)
    assert_difference("Comment.count", -1) { delete article_comment_url(@article, comments(:one)) }
    assert_redirected_to article_path(@article, anchor: "commenti")
  end

  test "l'HTML nei commenti non viene eseguito" do
    @article.comments.create!(name: "<b>Furbo</b>", email: "f@example.com", body: "<script>alert('xss')</script>ciao")
    get article_url(@article)
    assert_no_match(/<script>alert/, response.body)
    assert_no_match(/<b>Furbo<\/b>/, response.body)
  end

  # --- Capitolo 9: Ajax -----------------------------------------------------------------

  test "new.js: il form arriva come codice JavaScript, con l'HTML dentro una stringa escapata" do
    get new_article_comment_path(@article), xhr: true
    assert_response :success
    assert_equal "text/javascript", response.media_type
    assert_includes response.body, 'document.querySelector("#form-commento")'
    assert_includes response.body, "insertAdjacentHTML"
    assert_includes response.body, "comment[name]"
    assert_includes response.body, '<form class=\\"form\\"'      # l'HTML sta dentro una stringa JavaScript: le virgolette sono escapate (\")
    assert_no_match(%r{</}, response.body)              # ...e </ diventa <\/ (così un </script> non può chiudere lo script)
  end

  test "una GET che risponde JavaScript, se NON è una richiesta Ajax, viene rifiutata (protezione Rails)" do
    assert_raises(ActionController::InvalidCrossOriginRequest) do
      get new_article_comment_path(@article, format: :js)
    end
  end

  test "senza JavaScript la stessa route mostra una pagina con il form (invio normale, non Ajax)" do
    get new_article_comment_path(@article)
    assert_response :success
    assert_select "form[action='#{article_comments_path(@article)}']"
    assert_select "form[data-remote]", count: 0
  end

  test "il form caricato via Ajax invia via Ajax (data-remote)" do
    get new_article_comment_path(@article), xhr: true
    assert_match(/data-remote=\\"true\\"/, response.body)
  end

  test "create via Ajax: crea il commento e risponde JavaScript che lo aggiunge alla pagina" do
    assert_difference("@article.comments.count") do
      post article_comments_url(@article), params: commento(name: "Via Ajax"), xhr: true
    end
    assert_response :success
    assert_equal "text/javascript", response.media_type
    assert_includes response.body, '#commenti-lista'
    assert_includes response.body, "insertAdjacentHTML(\"beforeend\""
    assert_includes response.body, "Via Ajax"
    assert_includes response.body, "2 commenti"            # il titolo si aggiorna (c'era già un commento)
    assert_includes response.body, "Grazie per il commento!"
  end

  test "create via Ajax con un testo pieno di caratteri pericolosi non rompe il JavaScript" do
    post article_comments_url(@article),
         params: commento(body: %q(Virgolette " e ' e </script> e riga\nnuova), name: "<img onerror=x>"), xhr: true
    assert_response :success
    assert_no_match(%r{</script>}, response.body)           # escape_javascript trasforma </ in <\/
    assert_no_match(/<img onerror/, response.body)
  end

  test "create via Ajax non valido: 422 e JavaScript che ri-mostra il form con gli errori" do
    assert_no_difference("Comment.count") do
      post article_comments_url(@article), params: commento(name: "", body: "Da non perdere"), xhr: true
    end
    assert_response :unprocessable_entity
    assert_equal "text/javascript", response.media_type
    assert_includes response.body, "#form-commento"
    assert_includes response.body, "Nome è obbligatorio"
    assert_includes response.body, "Da non perdere"
  end

  test "destroy via Ajax: elimina e risponde JavaScript che toglie il commento dalla pagina" do
    log_in_as users(:one)
    assert_difference("Comment.count", -1) do
      delete article_comment_url(@article, comments(:one)), xhr: true
    end
    assert_response :success
    assert_equal "text/javascript", response.media_type
    assert_includes response.body, "#commento-#{comments(:one).id}"
    assert_includes response.body, ".remove()"
    assert_includes response.body, "Commento eliminato."
  end

  test "il link Elimina è remoto (Ajax)" do
    log_in_as users(:one)
    get article_url(@article)
    assert_select ".comment a.comment__delete[data-remote=true][data-method=delete]"
  end

  test "destroy via Ajax richiede comunque login e proprietà" do
    delete article_comment_url(@article, comments(:one)), xhr: true
    # Il redirect al login, per una richiesta Ajax, la gemma Turbolinks lo trasforma in JavaScript (status 200):
    assert_includes response.body, 'Turbolinks.visit("http://www.example.com/login"'
    assert Comment.exists?(comments(:one).id)         # nessun commento eliminato
    log_in_as users(:two)
    assert_raises(ActiveRecord::RecordNotFound) { delete article_comment_url(@article, comments(:one)), xhr: true }
  end
end
