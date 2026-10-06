# Capitolo 12 — Inviare e ricevere email: Action Mailer e Action Mailbox. Gli esempi, eseguibili.
#
# Esegui con:   PATH="$HOME/.local/bin:$PATH" bin/rails runner capitoli/capitolo12_esercizi.rb
#
# ATTENZIONE, come nel Capitolo 10: niente transazione da annullare. Le email in arrivo (Action Mailbox) sono
# salvate su disco (Active Storage) e il file esiste solo dopo il commit. Lo script crea dati veri e li
# elimina alla fine (blocco `ensure`): utente, articoli, email in arrivo e relativi file.
#
# Per le prove sugli invii uso delivery_method :test (le email finiscono in ActionMailer::Base.deliveries):
# nessuna email esce davvero dal computer.

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
  risultato = risultato[0, 230] + "…" if risultato.length > 230
  puts "=> #{risultato}"
rescue StandardError => e
  puts "!! #{e.class}: #{e.message.lines.first.to_s.strip[0, 200]}"
end

ActiveJob::Base.queue_adapter = :inline            # i job (instradamento delle email in arrivo…) girano subito
# Action Mailbox pianifica l'"incenerimento" delle email elaborate (di default dopo 30 giorni): è un job FUTURO,
# che l'adattatore inline non sa gestire. Lo disattivo qui (opzione config.action_mailbox.incinerate del libro).
ActionMailbox.incinerate = false
ActionMailer::Base.delivery_method = :test         # niente invii veri
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.deliveries.clear

articoli_prima = Article.count
utenti_prima = User.count
condividi(:radice, Rails.root)
condividi(:consegne, ActionMailer::Base.deliveries)

# ---------------------------------------------------------------------------
sezione "LA CONFIGURAZIONE: server di posta, credenziali, URL"
irb "Rails.application.credentials.config.keys"                              # le credenziali cifrate: i NOMI delle voci, non i valori
irb "Rails.application.credentials.smtp.keys"
irb "Rails.application.credentials.smtp[:user_name].include?('CAMBIA')"       # segnaposto: in sviluppo non si invia davvero
irb "Rails.env"
irb "Rails.application.config.action_mailer.delivery_method"                  # :file in sviluppo (le email in tmp/mails); sovrascritto qui da :test
irb "Rails.application.config.action_mailer.raise_delivery_errors"
irb "Rails.application.config.action_mailer.default_url_options"              # serve a costruire article_url(...) nelle email
irb "ApplicationMailer.default_params"                                        # il mittente predefinito
irb "ApplicationMailer._layout"                                               # il layout "mailer"
irb "File.exist?('app/views/layouts/mailer.html.erb') && File.exist?('app/views/layouts/mailer.text.erb')"

# ---------------------------------------------------------------------------
sezione "UN MAILER SOMIGLIA A UN CONTROLLER"
irb "NotifierMailer.superclass"
irb "NotifierMailer.action_methods.sort"                                      # i metodi pubblici = i messaggi che si possono creare
irb "Dir.glob('app/views/notifier_mailer/*').map { |f| File.basename(f) }.sort"   # un template per ogni formato (testo e HTML)
irb "Dir.glob('test/mailers/previews/*').map { |f| File.basename(f) }.sort"
irb "articolo = Article.published.first"
irb "messaggio = NotifierMailer.email_friend(articolo, 'Marco', 'amico@example.com')"
irb "messaggio.class"                                                         # ActionMailer::MessageDelivery: un involucro "pigro"
irb "consegne.size"                                                           # niente è stato ancora né costruito né inviato
irb "messaggio.message.class"                                                 # Mail::Message: il messaggio vero (qui viene costruito)
irb "messaggio.to"
irb "messaggio.from"
irb "messaggio.subject"
irb "messaggio.message.multipart?"
irb "messaggio.message.parts.map(&:mime_type)"
irb "messaggio.message.text_part.body.to_s"                                   # la versione in testo
irb "messaggio.message.html_part.body.to_s.scan(/href=\"[^\"]*\"/).first"     # il link all'articolo
irb "messaggio.message.attachments.map(&:filename)"                           # l'allegato è la copertina (se c'è)
irb "messaggio.message.attachments.first.body.decoded.bytesize"
irb "consegne.size"
irb "messaggio.deliver_now"                                                   # ORA si invia (deliver_later: in background, Capitolo 13)
irb "consegne.size"
irb "consegne.last.to"

puts "--- Gli argomenti arrivano al metodo del mailer come in un'azione di controller:"
irb "NotifierMailer.instance_method(:email_friend).parameters"

# ---------------------------------------------------------------------------
sezione "TESTO E HTML: l'escape dell'HTML cambia a seconda del formato"
irb "html = NotifierMailer.email_friend(articolo, '<b>Furbo</b>', 'amico@example.com').message.html_part.body.to_s"
irb "html.include?('&lt;b&gt;Furbo&lt;/b&gt;')"                              # nell'HTML il nome è neutralizzato
irb "html.include?('<b>Furbo</b>')"
irb "NotifierMailer.email_friend(articolo, 'Tom & Jerry', 'a@example.com').message.text_part.body.to_s.lines.first.strip"   # nel TESTO no: niente &amp;
puts "--- ...ma helper come truncate fanno comunque l'escape: nel testo serve escape: false"
irb "ApplicationController.helpers.truncate(\"L'ultimo tiro\", length: 40)"
irb "ApplicationController.helpers.truncate(\"L'ultimo tiro\", length: 40, escape: false)"

# ---------------------------------------------------------------------------
sezione "SALVARE LE EMAIL IN UN FILE (delivery_method :file: così in sviluppo)"
cartella = Rails.root.join("tmp/mails_prova").to_s
FileUtils.rm_rf(cartella)
condividi(:cartella, cartella)
irb "ActionMailer::Base.delivery_method = :file; ActionMailer::Base.file_settings = { location: cartella }; ActionMailer::Base.delivery_method"
irb "NotifierMailer.comment_added(Comment.new(article: articolo, name: 'Lettore', email: 'l@example.com', body: \"Bell'articolo!\")).deliver_now.class"
irb "ActionMailer::Base.delivery_method = :test"
irb "Dir.glob(File.join(cartella, '*')).map { |f| File.basename(f) }"         # un file per destinatario
irb "File.read(Dir.glob(File.join(cartella, '*')).first).lines.grep(/^(From|To|Subject|Content-Type):/).map(&:strip)"
FileUtils.rm_rf(cartella)

# ---------------------------------------------------------------------------
autore = nil
begin
  autore = User.create!(email: "autore12@example.com", password: "secret", password_confirmation: "secret")
  condividi(:autore, autore)

  sezione "L'AVVISO ALL'AUTORE QUANDO ARRIVA UN COMMENTO (il callback after_create del Capitolo 6)"
  irb "pubblicato = Article.create!(user: autore, title: 'Articolo di prova', body: '<p>Testo</p>', published_at: 1.day.ago)"
  irb "bozza = Article.create!(user: autore, title: 'Una bozza', body: '<p>Testo</p>')"
  irb "consegne.clear; commento = pubblicato.comments.create(name: 'Anna', email: 'anna@example.com', body: 'Bellissimo, grazie!')"
  irb "consegne.size"
  irb "consegne.last.to"                                                        # all'AUTORE dell'articolo
  irb "consegne.last.subject"
  irb "consegne.last.text_part.body.to_s.lines.map(&:strip).reject(&:empty?).first(3)"
  puts "--- Un commento non valido non scatena nessuna email (il callback after_create non parte):"
  irb "consegne.clear; pubblicato.comments.create(name: '', email: '', body: '').persisted?"
  irb "consegne.size"
  puts "--- Nemmeno su una bozza (la validazione lo impedisce):"
  irb "consegne.clear; bozza.comments.create(name: 'Anna', email: 'a@example.com', body: 'x').persisted?"
  irb "consegne.size"

  # -------------------------------------------------------------------------
  sezione "\"INVIA A UN AMICO\": il controller (richieste vere, senza login)"
  protezione = ActionController::Base.allow_forgery_protection
  ActionController::Base.allow_forgery_protection = false
  begin
    app = ActionDispatch::Integration::Session.new(Rails.application)
    app.host! "localhost"
    condividi(:app, app)
    irb "consegne.clear; app.get(\"/articles/\#{pubblicato.id}\")"
    irb "app.response.body.include?('class=\"friend-box\"')"                    # il riquadro <details> c'è
    irb "app.post(\"/articles/\#{pubblicato.id}/notify_friend\", params: {name: 'Marco', email: 'amico@example.com'})"
    irb "app.response.location"
    irb "app.flash[:notice]"
    irb "consegne.size"
    irb "consegne.last.to"
    irb "consegne.last.subject"
    puts "--- Indirizzo non valido, nome mancante, a-capo nel nome (header injection), bozza:"
    irb "consegne.clear; app.post(\"/articles/\#{pubblicato.id}/notify_friend\", params: {name: 'Marco', email: 'non-valida'})"
    irb "app.flash[:alert]"
    irb "app.post(\"/articles/\#{pubblicato.id}/notify_friend\", params: {name: '', email: 'a@example.com'})"
    irb "app.post(\"/articles/\#{pubblicato.id}/notify_friend\", params: {name: \"Marco\\r\\nBcc: spia@example.com\", email: 'a@example.com'})"
    irb "consegne.last.bcc"                                                     # nessun Bcc iniettato
    irb "consegne.last.subject.include?(\"\\n\")"
    irb "consegne.size"                                                         # solo l'ultimo (con il nome ripulito) è stato inviato
    irb "consegne.clear; app.post(\"/articles/\#{bozza.id}/notify_friend\", params: {name: 'Marco', email: 'a@example.com'})"
    irb "app.response.status"                                                   # 404: una bozza è invisibile a chi non è l'autore
    irb "consegne.size"
  ensure
    ActionController::Base.allow_forgery_protection = protezione
  end

  # -------------------------------------------------------------------------
  sezione "LE ANTEPRIME: vedere le email senza inviarle (solo in sviluppo)"
  irb "ActionMailer::Preview.all.map(&:name).sort"
  irb "NotifierMailerPreview.emails.sort"                                       # i metodi della preview = una anteprima ciascuno
  irb "app = ActionDispatch::Integration::Session.new(Rails.application); app.host!('localhost'); app.get('/rails/mailers/notifier_mailer/comment_added?part=text%2Fhtml')"
  irb "app.response.body.include?('Lettore Anonimo')"                           # i dati dell'anteprima
  irb "app.response.body.include?('Leggi e rispondi')"
  irb "Comment.where(email: 'lettore@example.com').count"                       # 0: la preview usa `build`, non `create`: non sporca il database

  # -------------------------------------------------------------------------
  sezione "ACTION MAILBOX: RICEVERE EMAIL — l'indirizzo segreto di ogni autore"
  irb "autore.draft_article_token.length"                                       # impostato da has_secure_token alla creazione
  irb "autore.draft_article_email.sub(autore.draft_article_token, '<token>')"
  irb "Rails.configuration.x.drafts_domain"
  irb "vecchio = autore.draft_article_token; autore.regenerate_draft_article_token; autore.draft_article_token != vecchio"
  irb "ActiveRecord::Base.connection.indexes(:users).map { |i| [i.columns, i.unique] }"   # indice unico sul token
  irb "ActionMailbox::InboundEmail.column_names"
  irb "ActionMailbox::InboundEmail.statuses.keys"                               # pending, processing, delivered, failed, bounced

  sezione "ACTION MAILBOX: dall'email alla bozza"
  def email_in_arrivo(a:, da: "autore12@example.com", oggetto: "Idea per un articolo", testo: "Primo paragrafo.\n\nSecondo\nsu due righe.", &blocco)
    mail = Mail.new({ to: a, from: da, subject: oggetto, body: testo }.compact, &blocco)
    # Creare l'email in arrivo basta: un callback (after_create_commit) la instrada da sola con un job (qui eseguito subito).
    # (Nei test, dove i job non girano, serve chiamare .route a mano: lo fa receive_inbound_email_from_source.)
    ActionMailbox::InboundEmail.create_and_extract_message_id!(mail.to_s)
  end
  condividi(:email_in_arrivo, method(:email_in_arrivo))
  irb "ApplicationMailbox.router.class"
  irb "indirizzo = autore.reload.draft_article_email"
  irb "consegne.clear; ricevuta = email_in_arrivo.call(a: indirizzo)"
  irb "ricevuta.reload.status"                                                  # delivered: elaborata con successo
  irb "bozza_via_email = Article.where(user_id: autore.id).order(:id).last     # (non autore.articles: ha un ordinamento predefinito per data)"
  irb "bozza_via_email.title"                                                   # oggetto → titolo
  irb "bozza_via_email.published?"                                              # una BOZZA: non pubblicata
  irb "bozza_via_email.body.body.to_html"                                       # testo semplice → paragrafi HTML
  irb "consegne.size"
  irb "consegne.last.to"                                                        # la conferma torna al mittente
  irb "consegne.last.subject"
  irb "consegne.last.text_part.body.to_s.include?(\"/articles/\#{bozza_via_email.id}/edit\")"   # col link per modificare la bozza

  puts "--- Visibilità: una bozza è visibile solo al suo autore"
  irb "Article.visible_to(nil).where(id: bozza_via_email.id).exists?"
  irb "Article.visible_to(User.first).where(id: bozza_via_email.id).exists?"
  irb "Article.visible_to(autore).where(id: bozza_via_email.id).exists?"

  puts "--- Un indirizzo inesistente: l'email RIMBALZA (bounce_with) e il mittente riceve una risposta"
  irb "consegne.clear; n = Article.count; sbagliata = email_in_arrivo.call(a: \"nonesiste@\#{Rails.configuration.x.drafts_domain}\")"
  irb "sbagliata.reload.status"
  irb "Article.count == n"
  irb "consegne.last.subject"
  puts "--- Senza oggetto non si crea nulla (il libro usa create! e l'elaborazione fallisce; qui si risponde):"
  irb "consegne.clear; senza = email_in_arrivo.call(a: autore.draft_article_email, oggetto: '')"
  irb "senza.reload.status"
  irb "consegne.last.subject"
  irb "consegne.last.text_part.body.to_s"
  puts "--- Email MULTIPART (testo + HTML): si usa la parte di solo testo"
  irb "m = email_in_arrivo.call(a: autore.draft_article_email, oggetto: 'Multipart', testo: nil) { text_part { body 'Testo semplice.' }; html_part { content_type 'text/html; charset=UTF-8'; body '<p>Versione <b>HTML</b></p>' } }"
  irb "autore.articles.find_by(title: 'Multipart').body.to_plain_text"
  puts "--- HTML nell'email: neutralizzato"
  irb "email_in_arrivo.call(a: autore.draft_article_email, oggetto: 'Con HTML', testo: \"<script>alert(1)</script> e <b>grassetto</b>\"); autore.articles.find_by(title: 'Con HTML').body.body.to_html"
  puts "--- Un'email a un altro dominio non corrisponde a nessuna mailbox:"
  irb "email_in_arrivo.call(a: 'qualcuno@altrodominio.it')"
  puts "--- Dopo aver rigenerato il token, il vecchio indirizzo non funziona più:"
  irb "vecchio_indirizzo = autore.draft_article_email; autore.regenerate_draft_article_token; n = Article.count; email_in_arrivo.call(a: vecchio_indirizzo).reload.status"
  irb "Article.count == n"
ensure
  # Pulizia: email in arrivo (e i loro file), articoli, utente.
  ActionMailbox::InboundEmail.find_each { |e| e.raw_email.purge; e.destroy }
  if autore
    Article.where(user_id: autore.id).find_each(&:destroy)
    autore.destroy
  end
  ActiveStorage::Blob.unattached.find_each(&:purge)
  FileUtils.rm_rf(cartella)
end

# ---------------------------------------------------------------------------
sezione "VERIFICA: tutto com'era prima?"
puts "Articoli: #{articoli_prima} → #{Article.count}   Utenti: #{utenti_prima} → #{User.count}   Email in arrivo: #{ActionMailbox::InboundEmail.count}"
puts(Article.count == articoli_prima && User.count == utenti_prima && ActionMailbox::InboundEmail.count == 0 ? "OK: i dati sono com'erano." : "ATTENZIONE: i dati sono cambiati!")
