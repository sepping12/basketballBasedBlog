# Capitolo 9 — JavaScript e CSS: asset pipeline, webpack, Turbolinks, Ajax. Le prove lato Rails.
#
# Esegui con:   bin/rails runner capitoli/capitolo9_esercizi.rb
#
# La parte lato BROWSER (il JavaScript che modifica davvero la pagina) si prova con:
#   capitoli/capitolo9_prova_ajax.js   (vedi le istruzioni in cima a quel file)
#
# Come nei capitoli precedenti, irb("codice") esegue il codice e stampa "=> risultato".
# Le richieste Ajax passano da route, filtri, controller e viste del blog, simulate in-process.
# Tutto ciò che scrive nel database gira in una transazione annullata.

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
  risultato = risultato[0, 250] + "…" if risultato.length > 250
  puts "=> #{risultato}"
rescue StandardError => e
  puts "!! #{e.class}: #{e.message.lines.first.to_s.strip[0, 200]}"
end

radice = Rails.root.to_s
condividi(:radice, radice)

# ---------------------------------------------------------------------------
sezione "DOVE VIVONO GLI ASSET: due sistemi, due cartelle"
puts "--- Asset Pipeline (Sprockets): CSS, immagini, font → app/assets"
irb "Dir.glob('app/assets/**/*').select { |f| File.file?(f) }.sort"
puts "--- webpack (Webpacker): JavaScript → app/javascript"
irb "Dir.glob('app/javascript/**/*').select { |f| File.file?(f) }.sort"
irb "Webpacker.config.source_path.relative_path_from(Rails.root).to_s"        # dove webpack legge i sorgenti
irb "Webpacker.config.source_entry_path.relative_path_from(Rails.root).to_s"  # i 'pack': i punti di ingresso
irb "Webpacker.config.public_output_path.relative_path_from(Rails.root).to_s" # dove scrive il risultato
irb "Rails.application.config.assets.paths.map { |p| p.to_s.sub(radice + '/', '') }.first(5)"   # dove Sprockets cerca

# ---------------------------------------------------------------------------
sezione "ASSET PIPELINE: il manifest concatena i fogli di stile"
puts "--- application.css è un MANIFEST: contiene solo commenti-direttiva, non regole CSS"
irb "File.read('app/assets/stylesheets/application.css').lines.grep(/require/).map(&:strip)"
irb "Dir.glob('app/assets/stylesheets/*').map { |f| [File.basename(f), File.size(f)] }"
puts "--- Sprockets concatena (require_tree .) e compila (Sass) i file in UN solo application.css:"
irb "css = Rails.application.assets.find_asset('application.css'); css.to_s.bytesize"
irb "css.to_s.include?('--orange')"                         # dentro c'è il contenuto di blog.css
irb "css.to_s.lines.size"
irb "ActionController::Base.helpers.stylesheet_link_tag('application').include?('/assets/application')"
puts "--- In produzione (assets:precompile) ogni file prende un'IMPRONTA nel nome: cambia il contenuto, cambia il nome,"
puts "--- e il browser può tenere il file in cache per sempre. Esempio reale di questo progetto:"
puts "    application-22676b96…c3c585eafa.css   (21.242 byte di sorgente → 17.565 minificato → 4.498 con gzip)"

# ---------------------------------------------------------------------------
sezione "WEBPACK: il JavaScript, in 'pack'"
puts "--- Il pack predefinito importa le librerie che servono a Rails:"
irb "File.read('app/javascript/packs/application.js').lines.grep(/require/).map(&:strip)"
irb "Webpacker.manifest.lookup('application.js').sub(/-\\h+\\.js/, '-<impronta>.js')"   # nome con impronta
irb "File.exist?(Webpacker.config.public_output_path.join('manifest.json'))"
irb "Webpacker.compiler.fresh?"                              # il pack è aggiornato rispetto ai sorgenti?
irb "Webpacker.config.compile?"                              # in sviluppo ricompila da solo quando serve
puts "--- Il layout include il pack e il foglio di stile, con data-turbolinks-track:"
irb "File.read('app/views/layouts/application.html.erb').lines.grep(/stylesheet_link_tag|javascript_pack_tag/).map(&:strip)"

# ---------------------------------------------------------------------------
sezione "TURBOLINKS: i link diventano richieste Ajax che sostituiscono il <body>"
irb "File.read('app/javascript/packs/application.js').include?('turbolinks')"
irb "ApplicationController.helpers.link_to('Lenta', '/articles', data: { turbolinks: false })"   # disattivato su UN link
irb "ApplicationController.helpers.link_to('Veloce', '/articles')"                                # attivo per tutti gli altri
irb "ApplicationController.render(inline: '<%= javascript_pack_tag \"application\", \"data-turbolinks-track\": \"reload\" %>').include?('data-turbolinks-track')"
puts "--- data-turbolinks-track=\"reload\": se cambia il file (nuova impronta), Turbolinks fa un ricaricamento completo"

# ---------------------------------------------------------------------------
sezione "AJAX: richieste XHR e risposte JavaScript (.js.erb)"
protezione_csrf = ActionController::Base.allow_forgery_protection
ActionController::Base.allow_forgery_protection = false
begin
  ActiveRecord::Base.transaction do
    autore = User.create!(email: 'autore9@example.com', password: 'secret', password_confirmation: 'secret')
    articolo = Article.create!(user: autore, title: 'Articolo per Ajax', body: 'Testo', published_at: 1.day.ago)
    condividi(:articolo, articolo)
    app = ActionDispatch::Integration::Session.new(Rails.application)
    app.host! "localhost"
    condividi(:app, app)

    puts "--- Il template giusto viene scelto dal FORMATO della richiesta, non dal solo nome dell'azione:"
    irb "ActionController::Base.new.lookup_context.exists?('comments/create', [], false, [], formats: [:js])"     # create.js.erb
    irb "ActionController::Base.new.lookup_context.exists?('comments/create', [], false, [], formats: [:html])"   # non esiste: lì si fa redirect
    irb "Dir.glob('app/views/comments/*.js.erb').map { |f| File.basename(f) }.sort"

    puts "--- 1) link_to ..., remote: true  → GET Ajax a new → new.js.erb"
    irb "ApplicationController.render(inline: \"<%= link_to 'Scrivi', '/x', remote: true, id: 'new_comment_link' %>\")"   # data-remote="true"
    irb "app.get(\"/articles/\#{articolo.id}/comments/new\", xhr: true)"
    irb "app.response.media_type"
    irb "app.response.body.lines.first.strip"
    irb "app.response.body.include?('insertAdjacentHTML')"
    irb "app.response.body.scan(/\\\\\\\"/).size > 0"           # l'HTML del form sta dentro una stringa JS: le virgolette sono escapate
    puts "--- La stessa GET che chiede JavaScript, ma NON da una richiesta Ajax, è rifiutata:"
    irb "app.get(\"/articles/\#{articolo.id}/comments/new.js\")"
    irb "app.get(\"/articles/\#{articolo.id}/comments/new\")"  # senza JavaScript: pagina HTML normale (nel libro: errore, non c'è new.html)
    irb "app.response.media_type"

    puts "--- 2) form_with è remoto (Ajax) per impostazione predefinita (Rails 6.0)"
    irb "ApplicationController.render(inline: \"<%= form_with(url: '/x') { |f| f.text_field :a } %>\").include?('data-remote=\"true\"')"
    irb "ApplicationController.render(inline: \"<%= form_with(url: '/x', local: true) { |f| f.text_field :a } %>\").include?('data-remote')"

    puts "--- 3) Invio di un commento via Ajax → create.js.erb"
    irb "app.post(\"/articles/\#{articolo.id}/comments\", params: {comment: {name: 'Ospite', email: 'o@example.com', body: 'Ciao'}}, xhr: true)"
    irb "app.response.media_type"
    irb "app.response.body.lines.map(&:strip).first(2)"
    irb "app.response.body.include?('1 commento')"            # il titolo si aggiorna
    irb "articolo.comments.count"
    puts "--- ...se il commento non è valido: 422 e JavaScript che ri-mostra il form con gli errori"
    irb "app.post(\"/articles/\#{articolo.id}/comments\", params: {comment: {name: '', email: '', body: ''}}, xhr: true)"
    irb "app.response.body.include?('Nome è obbligatorio')"
    irb "articolo.comments.count"

    puts "--- 4) Eliminare via Ajax → destroy.js.erb"
    app2 = ActionDispatch::Integration::Session.new(Rails.application)
    app2.host! "localhost"
    condividi(:app2, app2)
    irb "app2.post('/session', params: {email: 'autore9@example.com', password: 'secret'})"
    irb "commento = articolo.comments.first"
    irb "app2.delete(\"/articles/\#{articolo.id}/comments/\#{commento.id}\", xhr: true)"
    irb "app2.response.body.include?('.remove()')"
    irb "articolo.comments.count"

    puts "--- Un redirect su una richiesta Ajax: la gemma Turbolinks lo trasforma in JavaScript"
    irb "app.delete(\"/articles/\#{articolo.id}/comments/1\", xhr: true)"   # non loggato → filtro authenticate → redirect al login
    irb "app.response.body.lines.map(&:strip)"

    raise ActiveRecord::Rollback
  end
ensure
  ActionController::Base.allow_forgery_protection = protezione_csrf
end

# ---------------------------------------------------------------------------
sezione "JAVASCRIPT E DOM (nel browser): i selettori del capitolo"
puts "I template .js.erb usano questi metodi del DOM (verificati in jsdom da capitolo9_prova_ajax.js):"
puts "  document.querySelector('#commenti-lista')          → UN elemento (per id)"
puts "  document.querySelectorAll('.comment')              → una LISTA di elementi"
puts "  elemento.insertAdjacentHTML('beforeend', html)     → aggiunge HTML dentro l'elemento, in fondo"
puts "  elemento.classList.add('fade-in')                  → aggiunge una classe CSS (qui: l'animazione)"
puts "  elemento.remove()                                  → toglie l'elemento dalla pagina"
puts "  elemento.style.display = 'none'                    → nasconde un elemento"
puts "  elemento.textContent = '3 commenti'                → cambia il testo (mai interpretato come HTML)"
