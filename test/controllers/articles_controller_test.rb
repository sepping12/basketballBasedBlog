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
    assert_select ".card", count: Article.visible_to(users(:one)).count      # i pubblicati + le MIE bozze
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

# Capitolo 10: caricare, mostrare e rimuovere la copertina via web
class ArticlesCoverControllerTest < ActionDispatch::IntegrationTest
  setup do
    @article = articles(:one)          # dell'utente one
    log_in_as users(:one)
  end

  def upload(nome = "copertina.png", tipo = "image/png")
    fixture_file_upload("files/#{nome}", tipo)      # in Rails 6.0 il percorso parte da test/fixtures
  end

  test "il form ha il campo file e invia in multipart" do
    get new_article_url
    assert_select "form[enctype='multipart/form-data']"
    assert_select "input[type=file][name='article[cover_image]'][accept*='image/png']"
  end

  test "si crea un articolo con la copertina" do
    assert_difference(["Article.count", "ActiveStorage::Blob.count"]) do
      post articles_url, params: { article: { title: "Con foto", body: "Testo", cover_image: upload } }
    end
    article = Article.find_by!(title: "Con foto")
    assert article.cover_image.attached?
    assert_redirected_to article_url(article)
  end

  test "la pagina dell'articolo mostra la copertina grande (e subito, non lazy)" do
    attach_cover(@article).save!
    get article_url(@article)
    assert_select "figure.cover-figure img.cover-img[loading=eager][alt='#{@article.title}']"
    assert_select "figure.cover-figure img[src*='/rails/active_storage/representations/']"
  end

  test "elenco e home mostrano la copertina nelle schede; senza copertina c'è il pallone" do
    attach_cover(@article).save!
    altro = Article.create!(title: "Senza copertina", body: "<p>x</p>", user: users(:one), published_at: 1.day.ago)
    get articles_url
    visibili = Article.visible_to(users(:one)).count
    assert_equal 2, visibili
    assert_select ".card", count: visibili
    assert_select ".card__cover--photo img.cover-img[loading=lazy]", count: 1
    assert_select ".card__cover:not(.card__cover--photo) svg.ball", count: visibili - 1
    get root_url
    assert_select ".card__cover--photo img.cover-img", count: 1
  end

  test "la copertina non valida dà errore in italiano e non crea nulla" do
    assert_no_difference(["Article.count", "ActiveStorage::Attachment.count"]) do
      post articles_url, params: { article: { title: "x", body: "y", cover_image: upload("appunti.txt", "text/plain") } }
    end
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: "Copertina deve essere un'immagine JPEG, PNG, GIF o WebP"
  end

  test "il form di modifica mostra la miniatura attuale e la checkbox per rimuoverla" do
    attach_cover(@article).save!
    get edit_article_url(@article)
    assert_select ".cover-current img[alt='Copertina attuale']"
    assert_select ".cover-current input[type=checkbox][name='article[remove_cover_image]']"
  end

  test "senza copertina il form non mostra la checkbox di rimozione" do
    get edit_article_url(@article)
    assert_select ".cover-current", count: 0
  end

  test "spuntando 'Rimuovi questa immagine' la copertina viene eliminata" do
    attach_cover(@article).save!
    patch article_url(@article), params: { article: { remove_cover_image: "1" } }
    assert_redirected_to article_url(@article)
    assert_not @article.reload.cover_image.attached?
  end

  test "la checkbox non spuntata (valore 0) lascia la copertina" do
    attach_cover(@article).save!
    patch article_url(@article), params: { article: { title: "Nuovo titolo", remove_cover_image: "0" } }
    assert @article.reload.cover_image.attached?
  end

  test "si può sostituire la copertina caricandone un'altra" do
    attach_cover(@article).save!
    patch article_url(@article), params: { article: { cover_image: upload("panoramica.jpg", "image/jpeg") } }
    assert_equal "panoramica.jpg", @article.reload.cover_image.filename.to_s
  end

  test "modificando altri campi senza scegliere un file, la copertina resta" do
    attach_cover(@article).save!
    patch article_url(@article), params: { article: { title: "Solo il titolo" } }
    assert @article.reload.cover_image.attached?
  end

  test "un altro utente non può cambiare la copertina di un articolo non suo" do
    delete logout_path
    log_in_as users(:two)
    assert_raises(ActiveRecord::RecordNotFound) do
      patch article_url(@article), params: { article: { cover_image: upload } }
    end
    assert_not @article.reload.cover_image.attached?
  end

  test "l'API JSON include l'indirizzo dell'immagine originale, solo se c'è" do
    attach_cover(@article).save!
    Article.create!(title: "Senza copertina", body: "<p>x</p>", user: users(:one), published_at: 1.day.ago)
    get articles_url(format: :json)
    dati = JSON.parse(response.body)
    con = dati.find { |a| a["id"] == @article.id }
    senza = dati.find { |a| a["id"] != @article.id }
    assert_match %r{\Ahttp://www.example.com/rails/active_storage/blobs/}, con["cover_image_url"]
    assert_not senza.key?("cover_image_url")
  end

  test "la miniatura viene creata alla prima richiesta e restituisce un'immagine ridimensionata" do
    skip "ImageMagick non installato" unless imagemagick_disponibile?
    attach_cover(@article).save!
    get article_url(@article)
    url = css_select("figure.cover-figure img").first["src"]
    get url                                   # la rappresentazione risponde con un redirect al file vero
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_equal "image/png", response.media_type
    img = MiniMagick::Image.read(response.body)
    assert_operator img.width, :<=, 1200
    assert_equal [600, 400], [img.width, img.height]       # l'originale è più piccolo del limite: non si ingrandisce
  end
end

# Capitolo 11: testo formattato (Action Text + editor Trix)
class ArticlesRichTextControllerTest < ActionDispatch::IntegrationTest
  setup do
    @article = articles(:one)
    log_in_as users(:one)
  end

  test "il form ha l'editor Trix e il campo nascosto che invia l'HTML" do
    get edit_article_url(@article)
    assert_select "trix-editor[input]"
    assert_select "input[type=hidden][name='article[body]']"
    assert_select "trix-toolbar", count: 0          # la barra degli strumenti la crea il JavaScript di Trix nel browser
    assert_select "textarea[name='article[body]']", count: 0
  end

  test "il campo di testo contiene l'HTML già salvato (da modificare)" do
    @article.update!(body: "<p>Testo <strong>forte</strong></p>")
    get edit_article_url(@article)
    assert_select "input[type=hidden][name='article[body]'][value*='<strong>forte</strong>']"
  end

  test "si pubblica un articolo con testo formattato e la pagina lo mostra formattato" do
    html = "<h1>Titolo</h1><div>Un <strong>grassetto</strong> e un <em>corsivo</em></div><ul><li>uno</li><li>due</li></ul>"
    post articles_url, params: { article: { title: "Formattato", body: html } }
    get article_url(Article.find_by!(title: "Formattato"))
    assert_select ".prose .trix-content strong", text: "grassetto"
    assert_select ".prose .trix-content em", text: "corsivo"
    assert_select ".prose .trix-content h1", text: "Titolo"
    assert_select ".prose .trix-content ul li", count: 2
  end

  test "l'HTML pericoloso viene ripulito quando il testo viene mostrato (XSS)" do
    sporco = %(<div onclick="rubaDati()">Ciao</div><script>alert('xss')</script><a href="javascript:alert(1)">clic</a><strong>ok</strong>)
    post articles_url, params: { article: { title: "Sporco", body: sporco } }
    get article_url(Article.find_by!(title: "Sporco"))
    assert_no_match(/<script>alert/, response.body)
    assert_no_match(/onclick/, response.body)
    assert_no_match(/javascript:alert/, response.body)
    assert_select ".trix-content strong", text: "ok"
    assert_select ".trix-content", text: /Ciao/
  end

  test "un testo vuoto non si salva: errore e l'editor si ripresenta" do
    assert_no_difference("Article.count") do
      post articles_url, params: { article: { title: "Senza testo", body: "" } }
    end
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: "Testo è obbligatorio"
    assert_select "trix-editor"
  end

  test "la scheda dell'elenco mostra l'inizio del TESTO, senza tag, quando manca l'estratto" do
    @article.update!(excerpt: nil, body: "<p>Prima frase con <strong>grassetto</strong>.</p>")
    get articles_url
    assert_select ".card__excerpt", text: /Prima frase con grassetto\./
    assert_no_match(/&lt;strong/, response.body)
  end

  test "l'API JSON dà il testo semplice (body) e quello formattato (body_html)" do
    @article.update!(body: "<p>Testo <strong>forte</strong></p>")
    get articles_url(format: :json)
    dato = JSON.parse(response.body).find { |a| a["id"] == @article.id }
    assert_equal "Testo forte", dato["body"]
    assert_includes dato["body_html"], "<strong>forte</strong>"
    assert_includes dato["body_html"], "trix-content"
  end

  test "un altro utente non può modificare il testo di un articolo non suo" do
    delete logout_path
    log_in_as users(:two)
    assert_raises(ActiveRecord::RecordNotFound) do
      patch article_url(@article), params: { article: { body: "<p>Rubato</p>" } }
    end
    assert_includes @article.reload.body.to_plain_text, "Testo del primo articolo"
  end

  test "l'elenco fa lo stesso numero di query con 2 o con 12 articoli (with_rich_text_body: niente N+1)" do
    conta = lambda do
      n = 0
      cb = ->(*, payload) { n += 1 unless payload[:name].to_s =~ /SCHEMA/ || payload[:sql] =~ /SAVEPOINT|RELEASE|BEGIN|COMMIT/ }
      ActiveSupport::Notifications.subscribed(cb, "sql.active_record") { get articles_url }
      n
    end
    prima = conta.call
    10.times { |i| Article.create!(title: "Extra #{i}", user: users(:one), body: "<p>Testo #{i}</p>", published_at: 1.day.ago) }
    dopo = conta.call
    assert_equal prima, dopo, "le query dovrebbero restare #{prima}, sono diventate #{dopo}"
  end
end


# Capitolo 12: "Invia a un amico" (Action Mailer)
class ArticlesNotifyFriendTest < ActionDispatch::IntegrationTest
  setup { @article = articles(:one) }

  def invia(nome: "Marco", email: "amico@example.com", articolo: @article)
    post notify_friend_article_url(articolo), params: { name: nome, email: email }
  end

  test "la pagina dell'articolo ha il riquadro con il form (chiuso, senza JavaScript: <details>)" do
    get article_url(@article)
    assert_select "details.friend-box summary", text: /Invia questo articolo a un amico/
    assert_select "details.friend-box form[action='#{notify_friend_article_path(@article)}'][method=post]"
    assert_select "details.friend-box form input[name=name]"
    assert_select "details.friend-box form input[name=email]"
    assert_select "details.friend-box[open]", count: 0
  end

  test "l'invio è IN BACKGROUND: la richiesta accoda un job, non consegna nulla da sola" do
    assert_enqueued_emails(1) { invia }
    assert_emails(0) { }                               # nessuna consegna finché il job non gira
    assert_enqueued_with(job: ApplicationMailDeliveryJob, queue: "mailers")
    assert_empty ActionMailer::Base.deliveries
  end

  test "è pubblico: un visitatore non loggato può consigliare un articolo" do
    assert_emails(1) { invia }
    assert_redirected_to article_url(@article)
    assert_equal "Messaggio inviato al tuo amico.", flash[:notice]
    email = ActionMailer::Base.deliveries.last
    assert_equal ["amico@example.com"], email.to
    assert_includes email.subject, "Marco"
    assert_includes email.text_part.body.to_s, article_url(@article)
  end

  test "un indirizzo non valido non invia nulla e riporta al riquadro con un avviso" do
    ["non-una-email", "a@", "@b.it", "due persone@example.com", ""].each do |brutto|
      assert_no_emails { invia(email: brutto) }
      assert_redirected_to article_url(@article, anchor: "invia-amico")
      assert_equal "Scrivi il tuo nome e un indirizzo email valido.", flash[:alert]
    end
  end

  test "senza nome non invia nulla" do
    assert_no_emails { invia(nome: "   ") }
    assert_equal "Scrivi il tuo nome e un indirizzo email valido.", flash[:alert]
  end

  test "il nome è ripulito dagli a-capo (niente 'header injection') e accorciato a 60 caratteri" do
    assert_emails(1) { invia(nome: "Marco\r\nBcc: spia@example.com") }
    email = ActionMailer::Base.deliveries.last
    assert_nil email.bcc
    assert_no_match(/[\r\n]/, email.subject)
    assert_emails(1) { invia(nome: "x" * 100) }
    assert_equal 60, ActionMailer::Base.deliveries.last.text_part.body.to_s[/(x+)/, 1].length
  end

  test "un indirizzo troppo lungo viene rifiutato" do
    assert_no_emails { invia(email: "#{'a' * 250}@example.com") }
  end

  test "si consiglia un solo destinatario per richiesta" do
    assert_emails(1) { invia(email: "uno@example.com") }
    assert_equal ["uno@example.com"], ActionMailer::Base.deliveries.last.to
  end

  test "una bozza non si può consigliare (nemmeno dal suo autore)" do
    log_in_as users(:two)                      # la bozza è dell'utente two
    assert_no_emails { invia(articolo: articles(:two)) }
    assert_redirected_to article_url(articles(:two))
    assert_equal "Si possono consigliare solo articoli pubblicati.", flash[:alert]
  end

  test "e per gli altri una bozza non esiste proprio (404)" do
    assert_raises(ActiveRecord::RecordNotFound) { invia(articolo: articles(:two)) }
  end

  test "nella pagina di una bozza non c'è il riquadro 'invia a un amico'" do
    log_in_as users(:two)
    get article_url(articles(:two))
    assert_response :success
    assert_select "details.friend-box", count: 0
  end

  test "l'allegato: con una copertina l'email porta l'immagine" do
    attach_cover(@article).save!
    perform_enqueued_jobs { invia }          # con deliver_later l'email esce solo quando il job gira
    assert_equal ["copertina.png"], ActionMailer::Base.deliveries.last.attachments.map(&:filename)
  end

  test "solo POST: una GET su notify_friend non esiste" do
    assert_raises(ActionController::RoutingError) { get "/articles/#{@article.id}/notify_friend" }
  end
end

# Dal Capitolo 12 le bozze (articoli senza data di pubblicazione) non sono pubbliche
class ArticlesDraftsVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @pubblicato = articles(:one)               # dell'utente one
    @bozza = articles(:two)                    # bozza dell'utente two
  end

  test "scope visible_to: i pubblicati per tutti, le bozze solo al proprietario" do
    assert_equal [@pubblicato], Article.visible_to(nil).to_a
    assert_equal [@pubblicato], Article.visible_to(users(:one)).to_a
    assert_equal [@bozza.id, @pubblicato.id].sort, Article.visible_to(users(:two)).pluck(:id).sort
  end

  test "un visitatore non vede le bozze nell'elenco, nella home, nell'API né aprendole" do
    get articles_url
    assert_select ".card__title a", text: @bozza.title, count: 0
    get root_url
    assert_select ".card__title a", text: @bozza.title, count: 0
    get articles_url(format: :json)
    assert_not_includes JSON.parse(response.body).map { |a| a["id"] }, @bozza.id
    assert_raises(ActiveRecord::RecordNotFound) { get article_url(@bozza) }
    assert_raises(ActiveRecord::RecordNotFound) { get new_article_comment_url(@bozza) }
  end

  test "un altro utente loggato non le vede" do
    log_in_as users(:one)
    get articles_url
    assert_select ".card__title a", text: @bozza.title, count: 0
    assert_raises(ActiveRecord::RecordNotFound) { get article_url(@bozza) }
  end

  test "l'autore vede le proprie bozze, e la pagina funziona" do
    log_in_as users(:two)
    get articles_url
    assert_select ".card__title a", text: @bozza.title
    get article_url(@bozza)
    assert_response :success
    assert_select "h1", text: @bozza.title
  end

  test "il numero di articoli nella landing page conta solo i pubblicati" do
    get root_url
    assert_select ".hero__stats dt", text: Article.published.count.to_s
  end
end

class ArticlesDraftEmailAddressTest < ActionDispatch::IntegrationTest
  test "la pagina 'Scrivi' mostra all'autore il SUO indirizzo per le bozze" do
    log_in_as users(:one)
    get new_article_url
    assert_select "aside.tip a[href='mailto:#{users(:one).draft_article_email}']"
    assert_select "aside.tip", text: /bozza/
  end

  test "e non quello di un altro utente" do
    log_in_as users(:one)
    get new_article_url
    assert_no_match(/#{users(:two).draft_article_token}/, response.body)
  end
end

