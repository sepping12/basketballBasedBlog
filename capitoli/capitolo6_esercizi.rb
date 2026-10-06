# Capitolo 6 — Active Record avanzato: tutti gli esempi di console del capitolo.
#
# Esegui con:   bin/rails runner capitoli/capitolo6_esercizi.rb
#
# Come nei capitoli 4 e 5, irb("codice") esegue il codice e stampa il risultato "=>"
# (accorciato se troppo lungo). Tutto gira dentro una transazione che alla fine viene
# annullata: i dati del blog restano com'erano.
#
# Prerequisito: i modelli e le migrazioni del capitolo 6 (già fatti nel progetto).

def sezione(titolo)
  puts
  puts "=" * 70
  puts titolo
  puts "=" * 70
end

def irb(codice)
  puts "irb> #{codice}"
  risultato = eval(codice, TOPLEVEL_BINDING).inspect
  risultato = risultato[0, 230] + "…" if risultato.length > 230
  puts "=> #{risultato}"
rescue StandardError => e
  puts "!! #{e.class}: #{e.message.lines.first.to_s.strip}"
end

prima = {
  utenti: User.count, articoli: Article.count, categorie: Category.count,
  commenti: Comment.count, profili: Profile.count
}
puts "Stato prima: #{prima}"

ActiveRecord::Base.transaction do
  # ------------------------------------------------------------------------
  sezione "AGGIUNGERE METODI: il modello è una classe Ruby (Listato 6-1)"
  irb "a = Article.create!(title: 'Advanced Active Record', published_at: Date.today, body: 'Models need to relate to each other. In the real world, ..')"
  irb "Article.find(a.id).long_title"
  irb "Article.find(a.id).published?"

  # ------------------------------------------------------------------------
  sezione "ASSOCIAZIONI: cosa sa Active Record dei modelli"
  irb "Article.reflect_on_association(:comments).macro"
  irb "Article.reflect_on_association(:user).macro"
  irb "Article.reflect_on_association(:categories).macro"
  irb "User.reflect_on_association(:replies).options"
  irb "Article.column_names.include?('user_id')"   # la chiave esterna sta nella tabella con belongs_to

  # ------------------------------------------------------------------------
  sezione "UNO-A-UNO: User has_one Profile"
  irb "user = User.create(email: 'user@example.com', password: 'secret', password_confirmation: 'secret')"
  irb "user.persisted?"
  irb "user.hashed_password"
  irb "profile = Profile.create(name: 'John Doe', bio: 'Ruby developer trying to learn Rails')"
  irb "profile.persisted?"                         # false: manca l'utente
  irb "profile.errors.full_messages"               # belongs_to è anche una validazione di presenza
  irb "profile.user = user"
  irb "profile.save"
  irb "profile.user_id == user.id"
  irb "user.profile.name"
  irb "user.profile.destroy.destroyed?"
  irb "user.reload.profile"                        # niente profilo: nil
  irb "user.build_profile(name: 'Solo in memoria').persisted?"   # build: istanzia e collega, NON salva
  irb "user.create_profile(name: 'Jane Doe', color: 'pink').user_id == user.id"   # create: come build ma salva
  irb "user.profile.nil?"
  puts "--- Attenzione: se c'è già un profilo, build_profile/create_profile SOSTITUISCONO quello vecchio."
  puts "--- Con dependent: :destroy il vecchio viene ELIMINATO subito dal database, anche senza salvare il nuovo."
  irb "user.build_profile(name: 'Un secondo profilo').persisted?"
  irb "Profile.where(user_id: user.id).count"      # 0: il vecchio non c'è più

  # ------------------------------------------------------------------------
  sezione "UNO-A-MOLTI: User has_many Articles"
  irb "user = User.find_by(email: 'user@example.com')"
  irb "user.articles"                              # CollectionProxy vuota
  irb "user.articles << Article.find(a.id)"
  irb "user.articles.size"
  irb "Article.find(a.id).user_id == user.id"
  irb "Article.find(a.id).user.email"
  irb "user.articles << Article.new(title: 'One-to-many associations', body: 'One-to-many associations describe a pattern ..')"
  irb "user.article_ids.size"
  irb "user.articles.empty?"
  irb "user.articles.clear"                        # sgancia gli articoli: user_id → NULL (dependent: :nullify)
  irb "user.articles.count"
  irb "Article.where(title: ['Advanced Active Record', 'One-to-many associations']).count"   # gli articoli ESISTONO ancora
  irb "user.articles.create(title: 'Associations', body: 'Active Record makes working with associations easy..').persisted?"
  irb "user.articles.build(title: 'In memoria', body: 'x').user_id == user.id"
  irb "user.articles.map(&:title)"

  # ------------------------------------------------------------------------
  sezione "OPZIONI DELLE ASSOCIAZIONI: ordine predefinito e :dependent"
  irb "Article.where(user_id: user.id).delete_all"
  irb "user.articles.create!(title: 'Vecchio', body: 'x', published_at: '2020-01-01')"
  irb "user.articles.create!(title: 'Nuovo', body: 'x', published_at: '2026-10-01')"
  irb "user.articles.create!(title: 'Altro nuovo', body: 'x', published_at: '2026-10-01')"
  irb "user.articles.reload.map(&:title)"          # published_at DESC, poi title ASC
  irb "user.articles.to_sql"
  irb "ids = user.article_ids"
  irb "user.create_profile(name: 'Profilo da eliminare').persisted?"
  irb "user.destroy.destroyed?"                    # articoli: :nullify. profilo: :destroy (aggiunta rispetto al libro)
  irb "Profile.where(user_id: user.id).count"      # il profilo è stato eliminato con l'utente
  irb "Article.where(id: ids).pluck(:user_id)"     # gli articoli restano, senza autore
  puts "--- Senza :dependent il database protegge i riferimenti (chiave esterna):"
  irb "u2 = User.create!(email: 'u2@example.com', password: 'secret', password_confirmation: 'secret')"
  irb "art_u2 = Article.create!(title: 'Con autore', body: 'x', user: u2)"
  irb "User.delete(u2.id)"                         # delete salta i callback → il DB rifiuta
  irb "u2.destroy.destroyed?"                      # destroy esegue :nullify prima
  irb "art_u2.reload.user_id"

  # ------------------------------------------------------------------------
  sezione "MOLTI-A-MOLTI: has_and_belongs_to_many (Article ↔ Category)"
  irb "Article.reflect_on_association(:categories).join_table"
  irb "article = Article.create!(title: 'Articolo con categorie', body: 'x', published_at: Time.zone.now)"
  irb "cat = Category.find_by(name: 'Tattica')"
  irb "article.categories << cat"
  irb "article.categories.size"
  irb "cat.articles.pluck(:title).include?('Articolo con categorie')"   # funziona nei due versi
  irb "Category.all.pluck(:name)"                  # default_scope: ordine alfabetico
  irb "Category.unscoped.pluck(:name)"             # senza default_scope: ordine del database

  # ------------------------------------------------------------------------
  sezione "MOLTI-A-MOLTI RICCHI: has_many :through (User → articoli → commenti = replies)"
  irb "autore = User.create!(email: 'autore@example.com', password: 'secret', password_confirmation: 'secret')"
  irb "articolo = autore.articles.create!(title: 'Con commenti', body: 'x', published_at: Time.zone.now)"
  irb "autore.replies.empty?"
  irb "articolo.comments.create(name: 'Guest', email: 'guest@example.com', body: 'Great article!').persisted?"
  irb "autore.replies.size"
  irb "autore.replies.first.body"
  irb "autore.replies.to_sql"                      # un JOIN tra comments e articles

  # ------------------------------------------------------------------------
  sezione "RICERCA AVANZATA: where"
  irb "Article.where(title: 'Advanced Active Record').count"            # sintassi hash (AND tra le condizioni)
  irb "Article.where(\"title = 'Advanced Active Record'\").count"       # frammento SQL
  irb "Article.where(\"created_at > '2020-02-04' OR body NOT LIKE '%model%'\").count > 0"
  irb "Article.where('published_at < ?', Time.now).to_sql"              # condizioni array: il ? è sostituito in sicurezza
  irb "Article.where('created_at = ? OR body LIKE ?', Article.last.created_at, 'model').to_sql"
  irb "Article.where('title LIKE :search OR body LIKE :search', {search: '%association%'}).to_sql"   # segnaposto nominati
  irb "Article.where('title LIKE :search OR body LIKE :search', {search: '%association%'}).count > 0"

  puts
  puts "--- SQL INJECTION: perché NON si interpolano i dati dell'utente nelle stringhe SQL"
  irb "cattivo = \"x' OR '1'='1\""
  irb "Article.where(\"title = '\#{cattivo}'\").to_sql"      # MALE: la condizione diventa sempre vera
  irb "Article.where('title = ?', cattivo).to_sql"          # BENE: il valore viene messo tra apici in modo sicuro
  irb "Article.where(\"title = '\#{cattivo}'\").count == Article.count"   # MALE: restituisce TUTTI gli articoli
  irb "Article.where('title = ?', cattivo).count"           # BENE: nessun articolo

  # ------------------------------------------------------------------------
  sezione "ASSOCIATION PROXY: le ricerche limitate al proprietario"
  irb "mio = autore.articles.first"
  irb "altro = Article.create!(title: 'Di qualcun altro', body: 'x')"
  irb "autore.articles.find(mio.id).title"
  irb "autore.articles.find(altro.id)"            # non è suo: RecordNotFound
  irb "Article.find(altro.id).title"              # Article.find invece lo trova (nessun limite)
  irb "autore.articles.create(title: 'Privato', body: 'Body here..').user_id == autore.id"   # user_id impostato in automatico

  # ------------------------------------------------------------------------
  sezione "ALTRI FINDER: order, limit, joins, includes (concatenabili)"
  irb "Article.order('title ASC').limit(2).to_sql"
  irb "Article.order('title DESC').limit(2).pluck(:title).size"
  irb "Article.joins(:comments).to_sql"
  irb "Article.joins(:comments).distinct.pluck(:title)"
  irb "Article.includes(:comments).where(title: 'Con commenti').first.comments.size"

  # ------------------------------------------------------------------------
  sezione "SCOPE: default scope e named scope"
  irb "Category.all.to_sql"                        # default_scope: ORDER BY name
  irb "Article.published.count == Article.where.not(published_at: nil).count"
  irb "Article.draft.count"
  irb "Article.create!(title: 'Una bozza', body: 'x')"
  irb "Article.draft.where_title('bozza').pluck(:title)"           # scope concatenati
  irb "Article.where_title('Active').pluck(:title)"
  irb "Article.recent.to_sql"
  irb "Article.recent.pluck(:title).include?('Con commenti')"      # pubblicato adesso: è recente
  irb "Article.recent.pluck(:title).include?('Vecchio')"           # del 2020: non è recente
  irb "Article.published.recent.where_title('commenti').count"     # tre scope concatenati

  # ------------------------------------------------------------------------
  sezione "VALIDAZIONI INTEGRATE (User)"
  irb "User.new.valid?"
  irb "User.new.tap(&:valid?).errors.full_messages"
  irb "User.create!(email: 'dup@example.com', password: 'secret', password_confirmation: 'secret').persisted?"
  irb "d = User.new(email: 'dup@example.com', password: 'secret', password_confirmation: 'secret'); d.valid?"
  irb "d.errors.full_messages"                     # uniqueness
  irb "f = User.new(email: 'non-una-email', password: 'secret', password_confirmation: 'secret'); f.valid?"
  irb "f.errors.full_messages"                     # format
  irb "c = User.new(email: 'abc@example.com', password: 'secret', password_confirmation: 'altra'); c.valid?"
  irb "c.errors.full_messages"                     # confirmation: password_confirmation è un attributo virtuale
  irb "s = User.new(email: 'corta@example.com', password: 'abc', password_confirmation: 'abc'); s.valid?"
  irb "s.errors.full_messages"                     # length della password

  # ------------------------------------------------------------------------
  sezione "VALIDAZIONE PERSONALIZZATA (Comment) e CALLBACK"
  irb "bozza = Article.draft.first"
  irb "bozza.published?"
  irb "comment = bozza.comments.create(name: 'Dude', email: 'dude@example.com', body: 'Great article!')"
  irb "comment.persisted?"
  irb "comment.errors.full_messages"               # nessun commento su un articolo non pubblicato
  puts "--- Su un articolo pubblicato il commento si salva e scatta il callback after_create:"
  irb "ok = articolo.comments.create(name: 'Dude', email: 'dude@example.com', body: 'Great article!')"
  irb "ok.persisted?"

  # ------------------------------------------------------------------------
  sezione "IL MODELLO USER: password cifrata e autenticazione (Listato 6-34)"
  irb "user = User.create!(email: 'login@example.com', password: 'secret', password_confirmation: 'secret')"
  irb "user.hashed_password"
  irb "user.password"                              # l'accessor in memoria: sparisce quando ricarichi
  irb "User.find(user.id).password"                # dal DB: nil. La password in chiaro non è mai salvata
  irb "User.authenticate('login@example.com', 'secret') == user"
  irb "User.authenticate('login@example.com', 'secret2')"
  irb "User.authenticate('nessuno@example.com', 'secret')"
  irb "user.authenticated?('secret')"
  irb "second = User.find(user.id); second.update(email: 'login2@example.com')"   # senza password: valido, hash invariato
  irb "second.reload.hashed_password == user.hashed_password"
  irb "second.update(password: 'nuova1', password_confirmation: 'nuova1')"
  irb "second.reload.hashed_password == user.hashed_password"   # cambiata

  raise ActiveRecord::Rollback
end

# ---------------------------------------------------------------------------
sezione "VERIFICA: il database è com'era prima?"
dopo = {
  utenti: User.count, articoli: Article.count, categorie: Category.count,
  commenti: Comment.count, profili: Profile.count
}
puts "Prima: #{prima}"
puts "Dopo:  #{dopo}"
puts(prima == dopo ? "OK: il rollback ha annullato tutto." : "ATTENZIONE: il database è cambiato!")
