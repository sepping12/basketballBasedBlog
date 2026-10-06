# Capitolo 8 — Action Pack avanzato: utenti, commenti annidati, sessioni, filtri, escape, helper.
#
# Esegui con:   bin/rails runner capitoli/capitolo8_esercizi.rb
#
# Come nei capitoli precedenti, irb("codice") esegue il codice e stampa "=> risultato".
# Le richieste sono vere (route → filtri → controller → vista → layout) ma simulate in-process.
# Uso TRE "browser" separati, ognuno con i suoi cookie:
#   visitatore (mai loggato), autore (loggato, scrive gli articoli), altro (loggato, ma NON è l'autore).
# Tutto gira in una transazione annullata: i dati del blog restano com'erano.

def sezione(titolo)
  puts
  puts "=" * 72
  puts titolo
  puts "=" * 72
end

def condividi(nome, valore)
  TOPLEVEL_BINDING.local_variable_set(nome, valore)
end

def irb(codice)
  puts "irb> #{codice}"
  risultato = eval(codice, TOPLEVEL_BINDING).inspect
  risultato = risultato[0, 240] + "…" if risultato.length > 240
  puts "=> #{risultato}"
rescue StandardError => e
  puts "!! #{e.class}: #{e.message.lines.first.to_s.strip[0, 200]}"
end

def browser
  s = ActionDispatch::Integration::Session.new(Rails.application)
  s.host! "localhost"
  s
end

def log_righe(pattern, quante = 1)
  File.readlines(Rails.root.join("log/development.log")).grep(pattern).last(quante).map { |r| r.strip.gsub(/\e\[[0-9;]*m/, "") }
end

dati_prima = { utenti: User.count, articoli: Article.count, commenti: Comment.count }
protezione_csrf = ActionController::Base.allow_forgery_protection
ActionController::Base.allow_forgery_protection = false   # solo per lo script: le richieste simulate non hanno token

begin
  ActiveRecord::Base.transaction do
    # -----------------------------------------------------------------------
    sezione "RISORSE ANNIDATE: i commenti vivono dentro un articolo"
    routes = Rails.application.routes
    condividi(:routes, routes)
    irb "routes.url_helpers.article_comments_path(5)"            # POST: crea un commento per l'articolo 5
    irb "routes.url_helpers.article_comment_path(5, 9)"          # DELETE: elimina il commento 9 dell'articolo 5
    irb "routes.recognize_path('/articles/5/comments', method: :post)"
    irb "routes.recognize_path('/articles/5/comments/9', method: :delete)"
    irb "routes.recognize_path('/articles/5/comments', method: :get)"      # non esiste: i commenti si elencano dentro l'articolo
    puts "--- Il libro mappa tutte e 7 le azioni; qui solo quelle che esistono (only: [:create, :destroy]):"
    puts `bin/rails routes -c comments 2>&1`

    sezione "resource (singolare) vs resources: la sessione non ha un 'elenco'"
    class ProvaSessionsController < ActionController::Base; end
    class ProvaArticlesController < ActionController::Base; end
    confronto = ActionDispatch::Routing::RouteSet.new
    confronto.draw do
      resources :prova_articles   # 7 azioni, nomi al plurale, con index
      resource :prova_session     # 6 azioni, nomi al singolare, senza index e senza :id
    end
    condividi(:confronto, confronto)
    irb "confronto.routes.select { |r| r.defaults[:controller] == 'prova_articles' }.map { |r| \"#\" + r.defaults[:action] }.uniq.sort"
    irb "confronto.routes.select { |r| r.defaults[:controller] == 'prova_sessions' }.map { |r| r.defaults[:action] }.uniq.sort"
    irb "confronto.routes.select { |r| r.defaults[:controller] == 'prova_sessions' }.map { |r| r.path.spec.to_s }.uniq"   # nessun :id nell'URL
    puts "--- Le route di login/logout del blog:"
    irb "routes.url_helpers.login_path"
    irb "routes.url_helpers.session_path"
    irb "routes.url_helpers.logout_path"
    irb "routes.recognize_path('/logout', method: :delete)"
    irb "routes.recognize_path('/logout', method: :get)"          # il libro usa GET; qui no: una GET non deve modificare lo stato

    # -----------------------------------------------------------------------
    sezione "UTENTI: registrazione (UsersController, form con password_field)"
    visitatore = browser
    condividi(:visitatore, visitatore)
    irb "visitatore.get('/users/new')"
    irb "visitatore.response.body.include?('type=\"password\" name=\"user[password]\"')"
    irb "visitatore.post('/users', params: {user: {email: 'autore8@example.com', password: 'secret', password_confirmation: 'secret'}})"
    irb "visitatore.response.location"                           # registrato: si va al login
    irb "visitatore.flash[:notice]"
    irb "User.find_by(email: 'autore8@example.com').hashed_password"       # la password è cifrata: quella in chiaro non è salvata
    irb "visitatore.post('/users', params: {user: {email: 'non-una-email', password: 'abc', password_confirmation: 'xyz'}})"
    irb "visitatore.controller.view_assigns['user'].errors.full_messages"
    puts "--- Senza permit i parametri non si accettano (Listato 8-2: user_params restituiva `params`):"
    irb "visitatore.post('/users', params: {user: {email: 'furbo@example.com', password: 'secret', password_confirmation: 'secret', hashed_password: 'scelta-da-me'}})"
    irb "User.find_by(email: 'furbo@example.com').hashed_password == Digest::SHA1.hexdigest('secret')"   # hashed_password NON è permesso
    puts "log> " + log_righe(/Unpermitted parameter/).first.to_s
    irb "User.create!(email: 'altro8@example.com', password: 'secret', password_confirmation: 'secret').persisted?"

    # -----------------------------------------------------------------------
    sezione "SESSIONI: HTTP non ha stato, i cookie sì"
    irb "visitatore.get('/login')"
    irb "visitatore.cookies.to_hash.keys"                        # Rails ha messo un cookie di sessione
    irb "cookie_prima = visitatore.cookies['_blog_session']"
    irb "visitatore.response.body.include?('action=\"/session\"')"   # il form di login invia a session_path
    puts "--- Login SBAGLIATO: nessuna sessione, errore generico (flash.now)"
    irb "visitatore.post('/session', params: {email: 'autore8@example.com', password: 'sbagliata'})"
    irb "visitatore.request.session[:user_id]"
    irb "visitatore.response.body.include?('Email o password non corretti.')"
    irb "visitatore.post('/session', params: {email: 'nessuno@example.com', password: 'secret'})"   # stesso messaggio: non rivela se l'email esiste
    irb "visitatore.response.body.include?('Email o password non corretti.')"
    puts "--- Login GIUSTO: in sessione si salva SOLO l'id dell'utente"
    autore = browser
    condividi(:autore, autore)
    irb "autore.get('/login'); cookie_prima = autore.cookies['_blog_session']; nil"
    condividi(:cookie_prima, autore.cookies['_blog_session'])
    irb "autore.post('/session', params: {email: 'autore8@example.com', password: 'secret'})"
    irb "autore.response.location"
    irb "autore.flash[:notice]"
    irb "autore.request.session[:user_id] == User.find_by(email: 'autore8@example.com').id"
    irb "autore.cookies['_blog_session'] != cookie_prima"        # reset_session al login: nuovo cookie (protegge dalla "session fixation")
    irb "autore.cookies['_blog_session'].include?('user_id')"    # il cookie è CIFRATO: non si legge cosa contiene
    irb "autore.get('/')"
    irb "autore.response.body.include?('Esci') && autore.response.body.include?('Scrivi')"   # la navbar riconosce l'utente (current_user, logged_in?)
    irb "autore.response.body.include?('Registrati')"

    puts "--- Logout: DELETE /logout azzera la sessione"
    irb "autore.delete('/logout')"
    irb "autore.request.session[:user_id]"
    irb "autore.flash[:notice]"
    puts "--- ...e una GET su /logout non esiste più (nel libro è una GET: modifica lo stato)"
    irb "autore.get('/logout')"
    irb "autore.post('/session', params: {email: 'autore8@example.com', password: 'secret'})"   # rientro

    # -----------------------------------------------------------------------
    sezione "FILTRI: before_action :authenticate protegge le azioni"
    irb "ArticlesController._process_action_callbacks.select { |c| c.kind == :before }.map(&:filter)"
    irb "visitatore.get('/articles')"                            # index: pubblico
    irb "visitatore.get('/articles/#{Article.first.id}')"        # show: pubblico
    irb "visitatore.get('/articles/new')"                        # new: protetto
    irb "visitatore.response.location"
    irb "visitatore.flash[:alert]"
    irb "visitatore.request.session[:return_to]"                 # ricordata la pagina voluta
    irb "visitatore.post('/articles', params: {article: {title: 'Anonimo', body: 'x'}})"
    irb "Article.exists?(title: 'Anonimo')"
    irb "visitatore.get('/users/1/edit')"
    irb "visitatore.response.location"
    puts "--- Dopo il login si torna dove si voleva andare:"
    irb "visitatore.post('/session', params: {email: 'autore8@example.com', password: 'secret'})"
    irb "visitatore.response.location"
    irb "visitatore.delete('/logout')"

    # -----------------------------------------------------------------------
    sezione "PROPRIETÀ: current_user.articles.find invece di Article.find"
    irb "autore.post('/articles', params: {article: {title: 'Articolo di autore8', body: 'Testo', published_at: '2026-10-01 10:00', category_ids: ['', Category.find_by(name: 'Tattica').id, Category.find_by(name: 'NBA').id]}})"
    irb "articolo = Article.find_by(title: 'Articolo di autore8')"
    irb "articolo.user.email"                                    # assegnato da current_user.articles.new
    irb "articolo.categories.pluck(:name)"                       # category_ids: [] nei permit + check box → habtm
    irb "articolo.category_ids.size"
    irb "autore.get(\"/articles/\#{articolo.id}\")"
    irb "autore.response.body.include?('Modifica') && autore.response.body.include?('Elimina')"   # l'autore vede i controlli
    puts "--- Un altro utente loggato:"
    altro = browser
    condividi(:altro, altro)
    irb "altro.post('/session', params: {email: 'altro8@example.com', password: 'secret'})"
    irb "altro.get(\"/articles/\#{articolo.id}\")"
    irb "altro.response.body.include?('Elimina')"                # i link non compaiono
    irb "altro.get(\"/articles/\#{articolo.id}/edit\")"          # ...e anche forzando l'URL: 404 (RecordNotFound)
    irb "altro.patch(\"/articles/\#{articolo.id}\", params: {article: {title: 'Rubato'}})"
    irb "altro.delete(\"/articles/\#{articolo.id}\")"
    irb "articolo.reload.title"                                  # intatto
    irb "articolo.owned_by?(User.find_by(email: 'autore8@example.com'))"
    irb "articolo.owned_by?(User.find_by(email: 'altro8@example.com'))"
    irb "articolo.owned_by?(nil)"

    # -----------------------------------------------------------------------
    sezione "COMMENTI: create e destroy (CommentsController)"
    irb "visitatore.post(\"/articles/\#{articolo.id}/comments\", params: {comment: {name: 'Marco', email: 'marco@example.com', body: 'Bellissimo!'}})"
    irb "visitatore.response.location"
    irb "visitatore.flash[:notice]"
    irb "commento = articolo.comments.first"
    irb "visitatore.post(\"/articles/\#{articolo.id}/comments\", params: {comment: {name: '', email: '', body: ''}})"   # non valido
    irb "visitatore.controller.view_assigns['comment'].errors.full_messages"
    irb "visitatore.response.location"                           # nessun redirect: ri-mostra la pagina con gli errori
    bozza = Article.create!(user: User.find_by(email: 'altro8@example.com'), title: 'Bozza 8', body: 'x')
    condividi(:bozza, bozza)
    irb "visitatore.post(\"/articles/\#{bozza.id}/comments\", params: {comment: {name: 'A', email: 'a@b.it', body: 'x'}})"   # 404: dal Capitolo 12 una bozza è invisibile ai visitatori
    irb "altro.post(\"/articles/\#{bozza.id}/comments\", params: {comment: {name: 'A', email: 'a@b.it', body: 'x'}})"       # il suo autore la vede...
    irb "altro.controller.view_assigns['comment'].errors.full_messages"                                                    # ...ma non si può commentare un articolo non pubblicato

    puts "--- L'email dei commentatori non è pubblica:"
    irb "visitatore.get(\"/articles/\#{articolo.id}\"); visitatore.response.body.scan('marco@example.com').size"
    irb "autore.get(\"/articles/\#{articolo.id}\"); autore.response.body.scan('marco@example.com').size"   # solo l'autore dell'articolo la vede

    puts "--- Eliminare: serve il login E essere l'autore dell'articolo"
    irb "visitatore.delete(\"/articles/\#{articolo.id}/comments/\#{commento.id}\")"
    irb "visitatore.response.location"
    irb "altro.delete(\"/articles/\#{articolo.id}/comments/\#{commento.id}\")"   # loggato ma non autore: current_user.articles.find → 404
    irb "Comment.exists?(commento.id)"
    irb "autore.delete(\"/articles/\#{articolo.id}/comments/\#{commento.id}\")"
    irb "Comment.exists?(commento.id)"

    # -----------------------------------------------------------------------
    sezione "ESCAPE DELL'HTML: mai fidarsi dei dati degli utenti (XSS)"
    irb "ERB::Util.html_escape(\"<script>alert('xss')</script>\")"
    irb "ApplicationController.render(inline: '<%= testo %>', locals: {testo: \"<b>ciao</b>\"})"             # <%= %> fa l'escape da solo
    irb "ApplicationController.render(inline: '<%= testo.html_safe %>', locals: {testo: \"<b>ciao</b>\"})"    # html_safe lo DISATTIVA: pericoloso!
    irb "ApplicationController.helpers.simple_format(\"Riga uno\\n\\nRiga due\\nsulla stessa riga\")"
    irb "ApplicationController.helpers.simple_format(\"Ciao <script>alert('xss')</script> <b>vero</b>\")"      # simple_format toglie i tag pericolosi, tiene quelli sicuri
    irb "articolo.update!(title: \"<script>alert('titolo')</script>\", body: \"<script>alert('corpo')</script>Testo <b>in grassetto</b>\")"
    irb "autore.get(\"/articles/\#{articolo.id}\"); autore.response.body.include?('<script>alert')"             # false: né nel titolo né nel corpo
    irb "autore.response.body.include?('&lt;script&gt;alert(&#39;titolo&#39;)')"                                # il titolo è stato escapato

    # -----------------------------------------------------------------------
    sezione "FORM: categorie come checkbox (collection_check_boxes)"
    irb "autore.get(\"/articles/\#{articolo.id}/edit\")"
    irb "autore.response.body.scan(/type=\"checkbox\" value=\"\\d+\"/).size == Category.count"
    irb "autore.response.body.scan(/checked=\"checked\"/).size == articolo.category_ids.size"        # quelle dell'articolo sono già spuntate
    puts "--- category_ids e category_ids= li aggiunge has_and_belongs_to_many (Capitolo 6):"
    irb "articolo.category_ids = [Category.find_by(name: 'Storia').id]"
    irb "articolo.reload.categories.pluck(:name)"

    # -----------------------------------------------------------------------
    sezione "HELPER DI ACTION VIEW: link_to, numeri, testo, e uno nostro"
    h = "ApplicationController.helpers"
    irb "#{h}.link_to('New', '/articles/new', id: 'new_article_link')"
    puts "--- Con un hash di opzioni o con un oggetto servono le route: uso render inline"
    irb "ApplicationController.render(inline: \"<%= link_to 'New', {controller: 'articles', action: 'new'}, class: 'large' %>\")"   # due hash: graffe sul primo
    irb "ApplicationController.render(inline: \"<%= link_to 'Leggi', Article.find(\#{articolo.id}) %>\")"                             # un oggetto diventa la URL della sua show
    irb "#{h}.number_to_currency(1234.5, unit: '€', separator: ',', delimiter: '.', format: '%n %u')"
    irb "#{h}.number_to_percentage(66.666, precision: 1)"
    irb "#{h}.number_to_human_size(2_500_000)"
    irb "#{h}.number_with_delimiter(1234567)"
    irb "#{h}.truncate('Il pick and roll è la giocata più usata', length: 20)"
    irb "#{h}.pluralize(3, 'commento', 'commenti')"
    irb "#{h}.time_ago_in_words(3.hours.ago)"
    puts "--- Helper personalizzato submit_or_cancel (ApplicationHelper): pulsante + link Annulla"
    irb "ApplicationController.render(inline: \"<%= form_with(url: '/session', local: true) { |f| submit_or_cancel(f, 'Salva', '/articles') } %>\").gsub(/<input type=\"hidden\"[^>]*>/, '')"

    raise ActiveRecord::Rollback
  end
ensure
  ActionController::Base.allow_forgery_protection = protezione_csrf
end

# ---------------------------------------------------------------------------
sezione "VERIFICA: il database è com'era prima?"
dati_dopo = { utenti: User.count, articoli: Article.count, commenti: Comment.count }
puts "Prima: #{dati_prima}"
puts "Dopo:  #{dati_dopo}"
puts(dati_prima == dati_dopo ? "OK: il rollback ha annullato tutto." : "ATTENZIONE: il database è cambiato!")
