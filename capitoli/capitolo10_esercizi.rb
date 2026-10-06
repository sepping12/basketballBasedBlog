# Capitolo 10 — Active Storage: file allegati ai modelli. Gli esempi del capitolo, eseguibili.
#
# Esegui con:   PATH="$HOME/.local/bin:$PATH" bin/rails runner capitoli/capitolo10_esercizi.rb
#               (il PATH serve solo se ImageMagick è installato in ~/.local/bin, come in questo progetto)
#
# Come nei capitoli precedenti, irb("codice") esegue il codice e stampa "=> risultato".
# ATTENZIONE, diverso dagli altri capitoli: qui NON si può usare la transazione da annullare.
# Active Storage scrive il file su disco solo DOPO il commit (after_commit): dentro una transazione
# non ancora conclusa il file non esiste, e download/varianti darebbero FileNotFoundError.
# Quindi lo script crea dati veri e, alla fine (blocco `ensure`), elimina articoli, utente e file creati.

require "mini_magick"

# I job (per esempio l'analisi delle immagini) girano di solito in background; qui in modo sincrono,
# così lo script è deterministico e non si contende SQLite con i job in background.
ActiveJob::Base.queue_adapter = :inline

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
  risultato = risultato[0, 230] + "…" if risultato.length > 230
  puts "=> #{risultato}"
rescue StandardError => e
  puts "!! #{e.class}: #{e.message.lines.first.to_s.strip[0, 200]}"
end

def file_prova(nome)
  Rails.root.join("test/fixtures/files", nome)
end
condividi(:radice, Rails.root)

blob_prima = ActiveStorage::Blob.pluck(:id)
articoli_prima = Article.count
file_prima = Dir.glob(Rails.root.join("storage/**/*")).count { |f| File.file?(f) }

# ---------------------------------------------------------------------------
sezione "I PREREQUISITI: ImageMagick e la gemma image_processing"
irb "`magick -version`.lines.first.strip"
irb "Gem.loaded_specs['image_processing'].version.to_s"
irb "Gem.loaded_specs['mini_magick'].version.to_s"
irb "Rails.application.config.active_storage.service"                  # quale servizio usa questo ambiente
irb "ActiveStorage::Blob.service.class"
irb "ActiveStorage::Blob.service.root.to_s.sub(radice.to_s + '/', '')"  # dove salva i file: storage/
irb "Rails.application.config.active_storage.variant_processor"         # nil = predefinito di Rails 6.0: mini_magick

# ---------------------------------------------------------------------------
sezione "LE TABELLE: due, 'polimorfiche' (valgono per qualsiasi modello)"
irb "ActiveStorage::Blob.column_names"
irb "ActiveStorage::Attachment.column_names"
irb "Article.column_names.grep(/cover/)"                    # in articles non c'è nessuna colonna per il file
irb "Article.reflect_on_attachment(:cover_image).macro"
irb "Article.reflect_on_attachment(:cover_image).name"

# ---------------------------------------------------------------------------
autore = nil
begin
  autore = User.create!(email: 'autore10@example.com', password: 'secret', password_confirmation: 'secret')
  condividi(:autore, autore)

  sezione "ALLEGARE UN FILE: has_one_attached :cover_image"
  irb "articolo = Article.create!(user: autore, title: 'Con copertina', body: 'Testo', published_at: Time.current)"
  irb "articolo.cover_image.attached?"
  irb "articolo.cover_image.attach(io: File.open(file_prova('copertina.png')), filename: 'copertina.png', content_type: 'image/png')"
  irb "articolo.cover_image.attached?"
  irb "articolo.cover_image.filename.to_s"
  irb "articolo.cover_image.content_type"
  irb "articolo.cover_image.byte_size"
  irb "articolo.cover_image.blob.key.length"                  # chiave casuale con cui il file è salvato su disco
  irb "File.exist?(ActiveStorage::Blob.service.path_for(articolo.cover_image.key))"
  irb "articolo.cover_image.download.bytesize == File.size(file_prova('copertina.png'))"
  irb "articolo.cover_image.checksum.length"                  # impronta MD5 (base64): verifica che il file sia integro

  puts "--- Il record vero: una riga in 'attachments' che punta a un 'blob' e al record (con il NOME DELLA CLASSE)"
  irb "att = ActiveStorage::Attachment.find_by(record_id: articolo.id, name: 'cover_image')"
  irb "[att.record_type, att.name, att.record == articolo]"
  irb "att.blob == articolo.cover_image.blob"

  puts "--- L'analisi (larghezza e altezza) avviene in un job in background; qui la forzo:"
  irb "articolo.cover_image.blob.analyze; articolo.cover_image.blob.metadata.slice('width', 'height', 'analyzed')"

  # -------------------------------------------------------------------------
  sezione "LE VARIANTI: copie ridimensionate (creano ImageMagick)"
  irb "v = articolo.cover_image.variant(resize_to_limit: [100, 100])"
  irb "v.class"
  irb "v.variation.transformations"                           # cosa dobbiamo fare all'originale
  irb "v.processed.key.start_with?('variants/')"              # .processed: la crea (se non esiste già) e la salva
  irb "img = MiniMagick::Image.read(v.service.download(v.key)); [img.width, img.height]"
  irb "v.service.download(v.key).bytesize"
  irb "articolo.cover_image.byte_size"                        # l'originale resta com'era
  puts "--- resize_to_limit: sta DENTRO le dimensioni, mantenendo le proporzioni (e non ingrandisce mai)"
  irb "x = articolo.cover_image.variant(resize_to_limit: [1000, 1000]).processed; i = MiniMagick::Image.read(x.service.download(x.key)); [i.width, i.height]"
  puts "--- resize_to_fill: riempie le dimensioni ESATTE ritagliando i bordi (è quello che usano le schede)"
  irb "x = articolo.cover_image.variant(resize_to_fill: [300, 100]).processed; i = MiniMagick::Image.read(x.service.download(x.key)); [i.width, i.height]"
  irb "articolo.cover_image.variant(resize_to_fill: [300, 100]).variation.key == articolo.cover_image.variant(resize_to_fill: [300, 100]).variation.key"   # stessa variante = stessa chiave

  # -------------------------------------------------------------------------
  sezione "VALIDARE IL FILE (Rails 6.0 non ha validazioni integrate: le abbiamo scritte)"
  irb "a = Article.new(user: autore, title: 'x', body: 'y')"
  irb "a.cover_image.attach(io: File.open(file_prova('appunti.txt')), filename: 'appunti.txt', content_type: 'text/plain'); a.valid?"
  irb "a.errors.full_messages"
  irb "b = Article.new(user: autore, title: 'x', body: 'y')"
  irb "b.cover_image.attach(io: File.open(file_prova('logo.svg')), filename: 'logo.svg', content_type: 'image/svg+xml'); b.valid?"
  irb "b.errors.full_messages"
  irb "Article::COVER_TYPES"
  irb "Article::COVER_MAX_SIZE / 1.megabyte"
  puts "--- Limite noto: il tipo dichiarato da chi carica può mentire. Un file di testo chiamato .png:"
  irb "c = Article.new(user: autore, title: 'x', body: 'y')"
  irb "c.cover_image.attach(io: File.open(file_prova('appunti.txt')), filename: 'finta.png', content_type: 'image/png'); c.valid?"
  irb "c.cover_image.blob.content_type"                       # Active Storage guarda prima il contenuto; se non riconosce niente, si fida del nome/dichiarato
  irb "c.cover_image.blob.image?"
  puts "    (Mitigazioni: nosniff e download forzato dei tipi non-immagine, varianti sempre ricodificate da ImageMagick)"

  # -------------------------------------------------------------------------
  sezione "RIMUOVERE: purge e il campo virtuale remove_cover_image"
  irb "articolo.reload.cover_image.attached?"
  irb "articolo.remove_cover_image"                           # attr_accessor: esiste solo in memoria (nil)
  irb "articolo.update!(remove_cover_image: '0'); articolo.reload.cover_image.attached?"   # checkbox non spuntata: resta
  irb "chiave = articolo.cover_image.key"
  irb "articolo.update!(remove_cover_image: '1')"             # checkbox spuntata → after_save → purge
  irb "articolo.remove_cover_image"                           # azzerato dopo l'uso (nel libro restava '1' e cancellava anche la copertina successiva)
  irb "articolo.reload.cover_image.attached?"
  irb "File.exist?(ActiveStorage::Blob.service.path_for(chiave))"       # purge ha cancellato anche il FILE
  irb "ActiveStorage::Attachment.where(record_id: articolo.id).count"

  puts "--- detach vs purge: detach scollega e basta (il file resta, 'orfano'); purge elimina tutto"
  irb "articolo.cover_image.attach(io: File.open(file_prova('panoramica.jpg')), filename: 'panoramica.jpg', content_type: 'image/jpeg'); articolo.cover_image.attached?"
  irb "blob = articolo.cover_image.blob"
  irb "articolo.cover_image.detach; articolo.reload.cover_image.attached?"
  irb "ActiveStorage::Blob.unattached.where(id: blob.id).exists?"       # blob senza allegato: si pulisce con ActiveStorage::Blob.unattached.find_each(&:purge)

  # -------------------------------------------------------------------------
  sezione "PRESTAZIONI: with_attached_cover_image evita le query in più (N+1)"
  irb "5.times { |i| Article.create!(user: autore, title: \"Articolo \#{i}\", body: 'x').cover_image.attach(io: File.open(file_prova('copertina.png')), filename: 'copertina.png', content_type: 'image/png') }"
  conta = lambda do |&blocco|
    n = 0
    contatore = ->(*, payload) { n += 1 unless payload[:name] =~ /SCHEMA|TRANSACTION/ || payload[:sql] =~ /SAVEPOINT|RELEASE/ }
    ActiveSupport::Notifications.subscribed(contatore, "sql.active_record", &blocco)
    n
  end
  condividi(:conta, conta)
  irb "conta.call { Article.all.each { |a| a.cover_image.attached? } }"                           # una query per ogni articolo
  irb "conta.call { Article.with_attached_cover_image.each { |a| a.cover_image.attached? } }"     # 3 query in tutto, qualsiasi sia il numero di articoli
  irb "Article.count"

  # -------------------------------------------------------------------------
  sezione "NEL BROWSER: pagine, miniature e originali (richieste vere)"
  protezione = ActionController::Base.allow_forgery_protection
  ActionController::Base.allow_forgery_protection = false
  begin
    # un articolo con copertina già presente (dagli esempi dei dati seme)
    irb "seed = Article.joins(:cover_image_attachment).where.not(id: articolo.id).order(:id).first"
    app = ActionDispatch::Integration::Session.new(Rails.application)
    app.host! "localhost"
    condividi(:app, app)
    irb "seed.cover_image.attached?"
    irb "app.get(\"/articles/\#{seed.id}\")"
    irb "tag = app.response.body[/<img[^>]*cover-img[^>]*>/]; tag.sub(/src=\"[^\"]*\"/, 'src=\"…\"')"
    irb "url = app.response.body[/src=\"([^\"]*representations[^\"]*)\"/, 1]; url.sub(/\\A.*\\/rails/, '/rails')[0, 70]"
    irb "app.get(url)"                                          # la rappresentazione: redirect...
    irb "app.response.location.sub(/\\A.*\\/rails/, '/rails')[0, 60]"
    irb "app.get(app.response.location)"                        # ...al file vero (servizio Disk)
    irb "app.response.media_type"
    irb "i = MiniMagick::Image.read(app.response.body); [i.width, i.height]"
    irb "app.get('/articles')"
    irb "app.response.body.scan(/class=\"cover-img\"/).size >= 1"
    irb "app.response.body.scan('loading=\"lazy\"').size >= 1"                 # nelle schede: caricamento pigro
    irb "app.get(\"/articles/\#{seed.id}\"); app.response.body.include?('loading=\"eager\"')"     # nella pagina dell'articolo: subito
    irb "app.get('/articles.json'); JSON.parse(app.response.body).find { |a| a['cover_image_url'] }['cover_image_url'].sub(/\\A.*\\/rails/, '/rails')[0, 60]"
  ensure
    ActionController::Base.allow_forgery_protection = protezione
  end

ensure
  # Pulizia: file, articoli e utente creati dallo script (il rollback non basta: i file sono su disco).
  if autore
    Article.where(user_id: autore.id).find_each do |a|
      a.cover_image.purge if a.cover_image.attached?
      a.destroy
    end
    autore.destroy
  end
  ActiveStorage::Blob.where.not(id: blob_prima).find_each(&:purge)   # blob "orfani" (es. dopo detach)
end

# ---------------------------------------------------------------------------
sezione "VERIFICA: tutto com'era prima?"
file_dopo = Dir.glob(Rails.root.join("storage/**/*")).count { |f| File.file?(f) }
puts "Articoli: #{articoli_prima} → #{Article.count}"
puts "Utenti:   1 → #{User.count}"
puts "Blob:     #{blob_prima.size} → #{ActiveStorage::Blob.count}"
puts "File in storage/: #{file_prima} → #{file_dopo} (le varianti delle schede create vedendo il sito restano: sono una cache)"
puts(Article.count == articoli_prima && ActiveStorage::Blob.count == blob_prima.size && User.count == 1 ? "OK: i dati sono com'erano." : "ATTENZIONE: il database è cambiato!")
