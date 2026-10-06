# Capitolo 7 — Action Pack: route, controller e viste. Gli esempi del capitolo, eseguibili.
#
# Esegui con:   bin/rails runner capitoli/capitolo7_esercizi.rb
#
# Come nei capitoli precedenti, irb("codice") esegue il codice e stampa "=> risultato".
# Le richieste web sono vere (passano da route, controller, vista e layout del blog) ma
# simulate in-process con una "integration session" (è la variabile `app` della console).
# Tutto gira in una transazione annullata: i dati del blog restano com'erano.

def sezione(titolo)
  puts
  puts "=" * 70
  puts titolo
  puts "=" * 70
end

def irb(codice)
  puts "irb> #{codice}"
  risultato = eval(codice, TOPLEVEL_BINDING).inspect
  risultato = risultato[0, 260] + "…" if risultato.length > 260
  puts "=> #{risultato}"
rescue StandardError => e
  puts "!! #{e.class}: #{e.message.lines.first.to_s.strip[0, 200]}"
end

# Le variabili create fuori da irb() vanno "passate" al binding che irb() usa per valutare il codice.
def condividi(nome, valore)
  TOPLEVEL_BINDING.local_variable_set(nome, valore)
end

def log_righe(pattern, quante = 1)
  File.readlines(Rails.root.join("log/development.log")).grep(pattern).last(quante).map { |r| r.strip.gsub(/\e\[[0-9;]*m/, "") }
end

require "erb"

articoli_prima = Article.count

# ---------------------------------------------------------------------------
sezione "ERB: <% %> esegue, <%= %> esegue E stampa"
vista = <<~ERB
  <ul>
  <% articoli.each do |titolo| %>
    <li><%= titolo %></li>
  <% end %>
  </ul>
ERB
articoli = ["Pick and roll", "Tre punti"]
puts ERB.new(vista, trim_mode: "-").result(binding).gsub(/\n\s*\n/, "\n")
puts "--- Se dimentichi l'uguale non c'è errore, ma non stampa nulla (tag vuoti):"
irb 'ERB.new("<li><% 1 + 1 %></li>").result'
irb 'ERB.new("<li><%= 1 + 1 %></li>").result'

# ---------------------------------------------------------------------------
sezione "UN CONTROLLER È UNA CLASSE CON METODI PUBBLICI (le azioni)"
class CDPlayer
  def play;  "suona";   end
  def stop;  "ferma";   end
  def eject; stop + " ed espelle"; end   # può chiamare un metodo privato dall'interno

  private

  def calcola_tempo_residuo; 42; end
end
irb "player = CDPlayer.new"
irb "player.play"
irb "player.eject"
irb "player.pause"                             # non esiste: NoMethodError
irb "player.calcola_tempo_residuo"             # privato: non chiamabile da fuori
irb "player.respond_to?(:play)"
irb "ArticlesController.action_methods.sort"   # le azioni vere = i metodi PUBBLICI del controller
irb "ArticlesController.private_instance_methods(false).sort"   # set_article e article_params: privati, NON sono azioni

# ---------------------------------------------------------------------------
sezione "IL ROUTING: gli esempi del libro (un RouteSet separato, il blog non viene toccato)"
class TeamsController < ActionController::Base; end   # serve solo perché la route abbia un controller
rotte = ActionDispatch::Routing::RouteSet.new
rotte.draw do
  get "/teams/home", to: "teams#index"
  get "/teams/search/:query", to: "teams#search", as: "search"
end
condividi(:rotte, rotte)
irb "rotte.recognize_path('/teams/home')"
irb "rotte.recognize_path('/teams/search/toronto')"           # il terzo segmento diventa il parametro :query
irb "rotte.url_helpers.search_path(query: 'toronto')"         # named route (:as): genera il percorso...
irb "rotte.url_helpers.search_url(query: 'toronto', host: 'example.com')"   # ...o l'URL completo
irb "rotte.recognize_path('/non/esiste')"
puts "--- L'ORDINE conta: vince la prima route che corrisponde."
ordine = ActionDispatch::Routing::RouteSet.new
ordine.draw do
  get "/teams/:nome", to: "teams#show"
  get "/teams/home", to: "teams#index"        # non verrà mai raggiunta: la prima la intercetta
end
condividi(:ordine, ordine)
irb "ordine.recognize_path('/teams/home')"

# ---------------------------------------------------------------------------
sezione "LE ROUTE DEL BLOG: resources, named route, verbi HTTP"
routes = Rails.application.routes
condividi(:routes, routes)
irb "routes.url_helpers.articles_path"
irb "routes.url_helpers.article_path(7)"
irb "routes.url_helpers.edit_article_path(7)"
irb "routes.url_helpers.new_article_path"
irb "routes.url_helpers.root_path"
irb "routes.url_helpers.about_path"
puts "--- Stesso URL, verbi diversi → azioni diverse:"
irb "routes.recognize_path('/articles/5', method: :get)"
irb "routes.recognize_path('/articles/5', method: :patch)"
irb "routes.recognize_path('/articles/5', method: :delete)"
irb "routes.recognize_path('/articles', method: :post)"
puts "--- Elenco completo (equivale a: bin/rails routes -c articles):"
puts `bin/rails routes -c articles 2>&1`

# ---------------------------------------------------------------------------
protezione_csrf = ActionController::Base.allow_forgery_protection
ActionController::Base.allow_forgery_protection = false   # solo per questo script: le richieste simulate non hanno token

app = ActionDispatch::Integration::Session.new(Rails.application)
app.host! "localhost"
condividi(:app, app)

begin
  ActiveRecord::Base.transaction do
    # Dal Capitolo 8 scrivere richiede il login: creo un utente e faccio un login vero (POST /session).
    autore = User.create!(email: 'autore7@example.com', password: 'secret', password_confirmation: 'secret')
    altro_utente = User.create!(email: 'altro7@example.com', password: 'secret', password_confirmation: 'secret')
    condividi(:autore, autore)
    condividi(:altro_utente, altro_utente)
    app.post('/session', params: {email: 'autore7@example.com', password: 'secret'})

    # -----------------------------------------------------------------------
    sezione "IL CICLO DI RICHIESTA: route → controller → modello → vista → layout"
    irb "app.get('/articles')"                                  # restituisce lo status HTTP
    irb "app.controller.class"                                  # la route ha scelto ArticlesController...
    irb "app.controller.action_name"                            # ...e l'azione index
    irb "app.response.media_type"
    irb "app.controller.view_assigns.keys"                      # le @variabili che il controller passa alla vista
    irb "app.controller.view_assigns['articles'].class"
    irb "app.response.body.include?('<h1 class=\"page-head__title\">Tutti gli articoli</h1>')"   # contenuto di index.html.erb
    irb "app.response.body.include?('class=\"site-header\"')"   # la navbar viene dal LAYOUT (application.html.erb)
    irb "app.response.body.include?('class=\"site-footer\"')"   # il footer idem

    puts
    puts "--- Lo stesso URL in JSON: l'API 'gratis' dello scaffold"
    irb "app.get('/articles.json')"
    irb "app.response.media_type"
    irb "JSON.parse(app.response.body).first.keys"
    irb "app.get('/articles/#{Article.first.id}.json')"
    irb "JSON.parse(app.response.body)['title'] == Article.first.title"

    puts
    puts "--- Un id inesistente: find solleva RecordNotFound → Rails risponde 404"
    irb "app.get('/articles/999999')"

    # -----------------------------------------------------------------------
    sezione "I PARAMETRI DI RICHIESTA: params"
    irb "app.get('/articles?title=rails&body=great')"
    puts "log> " + log_righe(/Parameters:/).first.to_s     # lo stesso che il libro mostra nel terminale del server
    irb "app.get('/articles/#{Article.first.id}')"
    puts "log> " + log_righe(/Parameters:/).first.to_s     # l'id dell'URL finisce in params[:id]

    puts
    puts "--- STRONG PARAMETERS: params.require(:article).permit(...)"
    irb "params = ActionController::Parameters.new(article: {title: 'Ciao', body: 'Testo', admin: true})"
    irb "params[:article].permitted?"
    irb "Article.new(params[:article])"                         # il modello rifiuta parametri non filtrati
    irb "filtrati = params.require(:article).permit(:title, :body)"
    irb "filtrati.permitted?"
    irb "filtrati.to_h"                                         # 'admin' è sparito
    irb "Article.new(filtrati).title"
    irb "params.require(:nope)"                                 # se la chiave manca: ParameterMissing

    # -----------------------------------------------------------------------
    sezione "CREATE: successo = REDIRECT + messaggio flash"
    irb "app.post('/articles', params: {article: {title: 'Prova capitolo 7', body: 'Testo di prova'}})"   # (loggato come autore7)
    irb "app.response.location"                                 # redirect_to @article → /articles/ID
    irb "app.flash[:notice]"                                    # il messaggio che sopravvive al redirect
    irb "app.follow_redirect!"                                  # il browser segue il redirect con una nuova GET (200)
    irb "app.controller.action_name"
    irb "app.response.body.include?('Articolo pubblicato!')"    # la flash è nel layout (.toast)
    irb "app.get(app.request.path)"                             # ricarica: la flash sparisce
    irb "app.response.body.include?('Articolo pubblicato!')"

    sezione "CREATE: fallimento = RENDER (niente redirect), con errori"
    irb "app.post('/articles', params: {article: {title: '', body: ''}})"
    irb "app.response.location"                                 # nil: nessun redirect
    irb "app.controller.action_name"                            # create... ma ha renderizzato il template new
    irb "app.controller.view_assigns['article'].errors.full_messages"
    irb "app.response.body.include?('Titolo è obbligatorio')"
    irb "app.response.body.include?('field_with_errors')"       # Rails avvolge i campi errati: ci si appoggia il CSS
    irb "app.response.body.include?('name=\"article[title]\"')"  # il form si ripopola: stesso @article

    sezione "STRONG PARAMETERS in azione: un campo non permesso viene scartato"
    puts "--- Provo a creare un articolo a nome di un ALTRO utente passando user_id nel form:"
    irb "app.post('/articles', params: {article: {title: 'Hack', body: 'x', user_id: altro_utente.id}})"
    irb "Article.find_by(title: 'Hack').user_id == autore.id"   # true: user_id NON è nella lista permit; l'autore è chi ha fatto il login
    irb "Article.find_by(title: 'Hack').user_id == altro_utente.id"
    puts "log> " + log_righe(/Unpermitted parameter/).first.to_s

    sezione "EDIT e UPDATE: before_action trova l'articolo, update lo modifica"
    irb "a = Article.find_by(title: 'Prova capitolo 7')"
    irb "app.get(\"/articles/\#{a.id}/edit\")"
    irb "app.controller.view_assigns['article'] == a"           # set_article ha caricato lo stesso record
    irb "app.response.body.include?('Salva le modifiche')"      # stesso partial _form di new, ma con il bottone di modifica
    irb "app.patch(\"/articles/\#{a.id}\", params: {article: {title: 'Titolo modificato'}})"
    puts "log> " + log_righe(/Processing by ArticlesController#update/).first.to_s
    irb "a.reload.title"
    irb "app.flash[:notice]"
    irb "app.patch(\"/articles/\#{a.id}\", params: {article: {title: ''}})"   # update fallito: render :edit
    irb "app.response.location"

    sezione "DESTROY: redirect 303 all'elenco"
    irb "app.delete(\"/articles/\#{a.id}\")"
    irb "app.response.location"
    irb "app.flash[:notice]"
    irb "Article.exists?(a.id)"

    # -----------------------------------------------------------------------
    sezione "I LAYOUT: il guscio attorno a ogni pagina (<%= yield %>)"
    irb "ApplicationController.render(template: 'pages/about', layout: false).include?('<html')"   # senza layout: solo il template
    irb "ApplicationController.render(template: 'pages/about').include?('<html')"                  # con layout: pagina completa
    irb "ApplicationController.render(template: 'pages/about').include?('class=\"site-footer\"')"
    irb "ArticlesController._layout"                            # nil: nessun layout dichiarato → Rails usa application.html.erb

    # -----------------------------------------------------------------------
    sezione "FORM HELPER: FormHelper (legato al modello) e FormTagHelper (_tag)"
    irb "ApplicationController.render(inline: \"<%= form_with(model: Article.new, local: true) { |f| f.text_field :title } %>\").gsub(/<input type=\"hidden\" name=\"authenticity_token\"[^>]*>/, '')"
    puts "--- Con un articolo ESISTENTE: stesso helper, ma il metodo diventa PATCH e l'URL contiene l'id"
    irb "ApplicationController.render(inline: \"<%= form_with(model: Article.first, local: true) { |f| f.text_field :title } %>\").scan(/action=\"[^\"]*\"|name=\"_method\" value=\"[a-z]*\"|name=\"article\\[title\\]\"/)"
    irb "ApplicationController.helpers.text_field_tag(:q)"                        # versione _tag: non legata a un modello
    irb "ApplicationController.helpers.text_field_tag(:q, 'basket', class: 'large')"
    irb "ApplicationController.helpers.label_tag(:q, 'Cerca')"
    irb "ApplicationController.helpers.check_box_tag(:bozze)"
    irb "ApplicationController.helpers.pluralize(2, 'errore', 'errori')"
    irb "ApplicationController.helpers.link_to('Articoli', '/articles')"
    irb "ApplicationController.helpers.data_it(Time.zone.local(2026, 10, 6))"     # un nostro helper (ApplicationHelper)
    irb "ApplicationController.helpers.reading_time(Article.first)"               # un nostro helper (ArticlesHelper)

    # -----------------------------------------------------------------------
    sezione "I PARTIAL: variabili locali, oggetti e collezioni"
    irb "ApplicationController.render(partial: 'shared/ball', locals: {size: 20}).scan(/<svg class=\"ball\" width=\"\\d+\" height=\"\\d+\"/)"   # render 'shared/ball', size: 20
    puts "--- render @article cerca articles/_article.html.erb e crea la locale `article`"
    irb "ApplicationController.render(Article.first).scan(/<h3 class=\"card__title\">.*?<\\/h3>/m).first.gsub(/\\s+/, ' ')"
    puts "--- render @articles (collezione): il partial viene renderizzato una volta per elemento"
    irb "ApplicationController.render(Article.latest_first.limit(2)).scan('<article class=\"card\">').size"
    irb "ApplicationController.render(inline: '<%= render(Article.none).inspect %>')"   # collezione vuota: render restituisce nil (per questo nelle viste c'è `if @articles.any?`)

    raise ActiveRecord::Rollback
  end
ensure
  ActionController::Base.allow_forgery_protection = protezione_csrf
end

# ---------------------------------------------------------------------------
sezione "VERIFICA: il database è com'era prima?"
puts "Articoli prima: #{articoli_prima} — dopo: #{Article.count}"
puts(Article.count == articoli_prima ? "OK: il rollback ha annullato tutto." : "ATTENZIONE: il database è cambiato!")
