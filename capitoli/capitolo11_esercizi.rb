# Capitolo 11 — Action Text: testo formattato (rich text) con l'editor Trix. Gli esempi, eseguibili.
#
# Esegui con:   PATH="$HOME/.local/bin:$PATH" bin/rails runner capitoli/capitolo11_esercizi.rb
#
# Come nei capitoli precedenti, irb("codice") esegue il codice e stampa "=> risultato".
# I record sono creati in una transazione annullata. Il blob dell'esempio sugli allegati scrive un file
# su disco subito (non dopo il commit): viene eliminato (purge) prima del rollback.

require "open3"
require "fileutils"

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

ActiveJob::Base.queue_adapter = :inline
condividi(:radice, Rails.root)
condividi(:conta, lambda do |&blocco|
  n = 0
  cb = ->(*, payload) { n += 1 unless payload[:name].to_s =~ /SCHEMA/ || payload[:sql] =~ /SAVEPOINT|RELEASE|BEGIN|COMMIT/ }
  ActiveSupport::Notifications.subscribed(cb, "sql.active_record", &blocco)
  n
end)

# ---------------------------------------------------------------------------
sezione "L'INSTALLAZIONE: cosa ha fatto `rails action_text:install`"
puts "--- 1) Il CSS: un file in app/assets/stylesheets, incluso da solo grazie a `require_tree .`"
irb "File.exist?('app/assets/stylesheets/actiontext.scss')"
irb "File.read('app/assets/stylesheets/actiontext.scss').lines.grep(/require/).map(&:strip)"      # carica anche il CSS di Trix da node_modules
irb "Rails.application.assets.find_asset('application.css').to_s.include?('trix-editor')"
puts "--- 2) Il JavaScript: due dipendenze in package.json e due require nel pack"
irb "JSON.parse(File.read('package.json'))['dependencies'].select { |k, _| k =~ /trix|actiontext|rails\\/ujs|activestorage|actioncable/ }"
irb "File.read('app/javascript/packs/application.js').lines.grep(/trix|actiontext/).map(&:strip)"
irb "File.read('yarn.lock').include?('trix@')"                                  # versioni esatte fissate in yarn.lock
puts "--- 3) Il template per gli allegati e le fixture di esempio"
irb "File.exist?('app/views/active_storage/blobs/_blob.html.erb')"
irb "File.exist?('test/fixtures/action_text/rich_texts.yml')"
puts "--- 4) La tabella, polimorfica (come quella di Active Storage)"
irb "ActionText::RichText.column_names"
irb "ActionText::RichText.connection.indexes(:action_text_rich_texts).map { |i| [i.columns, i.unique] }"

# ---------------------------------------------------------------------------
sezione "has_rich_text :body — il modello"
irb "Article.reflect_on_association(:rich_text_body).macro"                     # un has_one nascosto
irb "Article.reflect_on_association(:rich_text_body).klass"
irb "Article.column_names.include?('body')"                                     # la colonna non c'è più
irb "articolo = Article.order(:id).first"
irb "articolo.body.class"                                                       # NON una stringa: un oggetto ActionText::RichText
irb "articolo.body.body.class"                                                  # ...che contiene un ActionText::Content
irb "articolo.body.record == articolo"
irb "articolo.body.name"
irb "articolo.body.to_plain_text[0, 90]"                                        # solo il testo
irb "articolo.body.to_s[0, 100]"                                                # l'HTML, avvolto in <div class=\"trix-content\">
irb "articolo.body.body.to_html[0, 60]"                                         # l'HTML "grezzo", senza il contenitore
irb "Article.respond_to?(:with_rich_text_body)"                                 # lo scope per evitare le query N+1

# ---------------------------------------------------------------------------
sezione "I DATI MIGRATI: dalla colonna articles.body alla tabella di Action Text"
irb "ActionText::RichText.where(record_type: 'Article', name: 'body').count == Article.count"
irb "ActionText::RichText.where(record_type: 'Article').order(:record_id).pluck(:record_id, :name)"
irb "grezzo = ActionText::RichText.connection.select_value('SELECT body FROM action_text_rich_texts ORDER BY record_id LIMIT 1')"   # com'è nel DB
irb "grezzo[0, 80]"                                                              # <p>…</p>: paragrafi veri (la migrazione li ha costruiti)
irb "grezzo.scan('</p>').size"

# ---------------------------------------------------------------------------
blob_prima = ActiveStorage::Blob.pluck(:id)
condividi(:blob_prima, blob_prima)
ActiveRecord::Base.transaction do
  autore = User.create!(email: 'autore11@example.com', password: 'secret', password_confirmation: 'secret')
  condividi(:autore, autore)

  sezione "ASSEGNARE E LEGGERE IL TESTO FORMATTATO"
  irb "a = Article.create!(user: autore, title: 'Prova rich text', body: '<h1>Titolo</h1><div>Un <strong>grassetto</strong> e un <em>corsivo</em></div><ul><li>uno</li><li>due</li></ul>')"
  irb "a.body.to_s"                                                              # HTML avvolto
  irb "a.body.to_plain_text"                                                     # testo semplice, con gli elenchi leggibili
  irb "a.body.body.to_trix_html"                                                 # la versione per l'editor (con la sintassi di Trix)
  irb "a.body.blank?"
  irb "a.body.present?"
  irb "a.update!(body: '<p>Nuovo testo</p>'); a.reload.body.to_plain_text"
  puts "--- La validazione di presenza (validates :title, :body, presence: true) vale anche per il rich text:"
  irb "v = Article.new(user: autore, title: 'x', body: '')"
  irb "v.valid?"
  irb "v.errors.full_messages"
  irb "w = Article.new(user: autore, title: 'x', body: '<div><br></div>'); w.valid?"          # un editor 'vuoto' (solo un a-capo)
  irb "ActionText::RichText.where(record_id: a.id).count"
  puts "--- Eliminare: destroy elimina anche il testo; delete NO (salta i callback → riga orfana)"
  irb "b = Article.create!(user: autore, title: 'Da eliminare', body: '<p>x</p>'); id_b = b.id; b.destroy; ActionText::RichText.where(record_type: 'Article', record_id: id_b).count"
  irb "c = Article.create!(user: autore, title: 'Da eliminare 2', body: '<p>x</p>'); id_c = c.id; Article.delete(id_c); ActionText::RichText.where(record_type: 'Article', record_id: id_c).count"
  irb "ActionText::RichText.where(record_type: 'Article', record_id: id_c).delete_all"

  # -------------------------------------------------------------------------
  sezione "SANIFICAZIONE: l'HTML pericoloso viene ripulito quando si MOSTRA il testo"
  sporco = %q(<div onclick="rubaDati()">Ciao</div><script>alert('xss')</script><a href="javascript:alert(1)">clic</a><a href="https://esempio.it" target="_blank">link vero</a><strong>ok</strong><iframe src="https://x"></iframe>)
  condividi(:sporco, sporco)
  irb "d = Article.create!(user: autore, title: 'Sporco', body: sporco)"
  irb "d.body.body.to_html"                                                      # nel DATABASE resta com'è stato inviato...
  irb "d.body.to_s"                                                              # ...ma in VISUALIZZAZIONE viene ripulito
  irb "d.body.to_s.include?('<script')"
  irb "d.body.to_s.include?('onclick')"
  irb "d.body.to_s.include?('javascript:')"
  irb "d.body.to_s.include?('iframe')"
  irb "d.body.to_s.include?('<strong>ok</strong>')"                              # i tag innocui restano
  irb "d.body.to_s.include?('href=\"https://esempio.it\"')"
  irb "ActionText::ContentHelper.allowed_tags.to_a.sort.first(12)"               # alcuni dei tag ammessi
  irb "ActionText::ContentHelper.allowed_attributes.to_a.sort.first(8)"

  # -------------------------------------------------------------------------
  sezione "CERCARE NEL TESTO: ora serve un join con la tabella dei rich text"
  irb "Article.where(\"body LIKE '%pick%'\").count"                              # non funziona più: body non è una colonna
  irb "Article.joins(:rich_text_body).where('action_text_rich_texts.body LIKE ?', '%pick and roll%').pluck(:title)"
  irb "Article.joins(:rich_text_body).where('action_text_rich_texts.body LIKE ?', '%grassetto%').pluck(:title)"
  puts "    (Attenzione: si cerca nell'HTML, quindi anche nei tag. Per ricerche serie: Postgres full-text, o una colonna con il testo semplice.)"

  # -------------------------------------------------------------------------
  sezione "PRESTAZIONI: with_rich_text_body evita le query N+1"
  irb "4.times { |i| Article.create!(user: autore, title: \"Extra \#{i}\", body: \"<p>Testo \#{i}</p>\") }"
  irb "Article.count"
  irb "conta.call { Article.all.each { |x| x.body.to_plain_text } }"
  irb "conta.call { Article.with_rich_text_body.each { |x| x.body.to_plain_text } }"
  irb "conta.call { Article.with_rich_text_body.with_attached_cover_image.includes(:categories).each { |x| x.body.to_plain_text; x.cover_image.attached?; x.categories.to_a } }"

  # -------------------------------------------------------------------------
  sezione "IL FORM E LE PAGINE (richieste vere)"
  protezione = ActionController::Base.allow_forgery_protection
  ActionController::Base.allow_forgery_protection = false
  begin
    app = ActionDispatch::Integration::Session.new(Rails.application)
    app.host! "localhost"
    condividi(:app, app)
    irb "app.post('/session', params: {email: 'autore11@example.com', password: 'secret'})"
    irb "app.get(\"/articles/\#{a.id}/edit\")"
    irb "app.response.body.scan(/<trix-editor[^>]*>/).first.sub(/id=\"[^\"]*\"/, 'id=\"…\"')"
    irb "app.response.body[/<input[^>]*type=\"hidden\"[^>]*name=\"article\\[body\\]\"[^>]*>/].sub(/id=\"[^\"]*\"/, 'id=\"…\"')"    # il campo nascosto che invia l'HTML
    irb "app.response.body.include?('<textarea')"                                # niente più textarea: c'è l'editor
    irb "app.post('/articles', params: {article: {title: 'Via web', body: '<div>Un <strong>forte</strong></div>'}})"
    irb "nuovo = Article.find_by(title: 'Via web')"
    irb "app.get(\"/articles/\#{nuovo.id}\")"
    irb "app.response.body[/<div class=\"trix-content\">.*?<\\/div>\\s*<\\/div>/m].gsub(/\\s+/, ' ')"
    irb "app.get('/articles.json'); JSON.parse(app.response.body).find { |x| x['title'] == 'Via web' }.slice('body', 'body_html').transform_values { |v| v.gsub(/\\s+/, ' ') }"
  ensure
    ActionController::Base.allow_forgery_protection = protezione
  end

  # -------------------------------------------------------------------------
  sezione "IMMAGINI INCORPORATE NEL TESTO (Action Text + Active Storage)"
  irb "blob = ActiveStorage::Blob.create_after_upload!(io: File.open(radice.join('test/fixtures/files/copertina.png')), filename: 'copertina.png', content_type: 'image/png')"
  irb "allegato = ActionText::Attachment.from_attachable(blob)"
  irb "allegato.to_html[0, 110]"                                                 # un tag <action-text-attachment sgid=\"…\"> (firmato)
  irb "e = Article.create!(user: autore, title: 'Con foto', body: \"<p>Guarda:</p>\#{allegato.to_html}\")"
  irb "e.body.embeds.map { |x| x.blob.filename.to_s }"                           # i file incorporati
  irb "e.body.to_plain_text"                                                     # nel testo semplice compare il nome del file
  irb "ActiveStorage::Attachment.find_by(blob_id: blob.id).record_type"          # l'allegato appartiene al RichText, non all'articolo
  irb "e.body.to_s.include?('<figure')"                                          # reso con il partial active_storage/blobs/_blob.html.erb
  irb "e.body.to_s.include?('/rails/active_storage/')"
  # Pulizia: tolgo l'allegato dal testo (così il blob si può eliminare) e cancello il file creato su disco.
  irb "e.update!(body: '<p>senza foto</p>')"
  irb "ActiveStorage::Blob.where.not(id: blob_prima).find_each(&:purge); ActiveStorage::Blob.count == blob_prima.size"

  raise ActiveRecord::Rollback
end

# ---------------------------------------------------------------------------
sezione "LA MIGRAZIONE È REVERSIBILE (su una COPIA del database, non sul tuo)"
copia = Rails.root.join("tmp/copia_cap11.sqlite3").to_s
FileUtils.cp(Rails.root.join("db/development.sqlite3"), copia)
# SCHEMA=…: i comandi sulla copia scrivono lo schema in un file temporaneo, senza toccare db/schema.rb
# (riscrivere un file osservato da Rails in sviluppo farebbe ricaricare le classi a metà script).
env = { "DATABASE_URL" => "sqlite3:#{copia}", "SCHEMA" => Rails.root.join("tmp/schema_copia.rb").to_s }
rb, = Open3.capture2e(env, "bin/rails", "db:rollback", "STEP=2")
puts "irb> bin/rails db:rollback STEP=2   (sulla copia)"
puts rb.lines.grep(/reverting|reverted/).map { |l| "     " + l.strip }
irb "ActiveRecord::Base.connection.select_value(\"SELECT COUNT(*) FROM pragma_table_info('articles') WHERE name = 'body'\") " \
    "# nel DB reale: 0"                                                                # (il DB reale non è stato toccato)
copia_db = SQLite3::Database.new(copia)
condividi(:copia_db, copia_db)
irb "copia_db.execute(\"SELECT COUNT(*) FROM pragma_table_info('articles') WHERE name = 'body'\").flatten"     # nella copia: 1 → la colonna è tornata
irb "copia_db.execute(\"SELECT substr(body, 1, 50) FROM articles ORDER BY id LIMIT 1\").flatten"               # ...con il testo (semplice) rimesso dentro
irb "copia_db.execute(\"SELECT COUNT(*) FROM action_text_rich_texts WHERE record_type = 'Article'\").flatten"  # i rich text sono stati tolti
ra, = Open3.capture2e(env, "bin/rails", "db:migrate")
puts "irb> bin/rails db:migrate   (sulla copia)"
puts ra.lines.grep(/migrated \(/).map { |l| "     " + l.strip[0, 60] }
irb "copia_db.execute(\"SELECT COUNT(*) FROM action_text_rich_texts WHERE record_type = 'Article'\").flatten"   # di nuovo 4
irb "copia_db.execute(\"SELECT COUNT(*) FROM pragma_table_info('articles') WHERE name = 'body'\").flatten"     # colonna di nuovo tolta
copia_db.close
FileUtils.rm_f([copia, Rails.root.join("tmp/schema_copia.rb").to_s])
irb "Article.column_names.include?('body')"                                     # il DB vero non è stato toccato

# ---------------------------------------------------------------------------
sezione "VERIFICA: tutto com'era prima?"
puts "Articoli: #{Article.count}, rich text: #{ActionText::RichText.count}, utenti: #{User.count}, blob: #{ActiveStorage::Blob.count}"
puts(Article.count == 4 && ActionText::RichText.count == 4 && User.count == 1 && ActiveStorage::Blob.count == blob_prima.size ? "OK: i dati sono com'erano." : "ATTENZIONE: il database è cambiato!")
