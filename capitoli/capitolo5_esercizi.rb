# Capitolo 5 — Lavorare con un database: Active Record. Tutti gli esempi della console.
#
# Esegui con:   bin/rails runner capitoli/capitolo5_esercizi.rb
#
# Come nel capitolo 4, irb("codice") esegue il codice e stampa il risultato "=>".
#
# SICUREZZA: il libro parte con `rails db:reset`, che CANCELLA il database.
# Qui non lo facciamo: tutto gira dentro una transazione che alla fine viene
# annullata (ActiveRecord::Rollback). Gli articoli del blog restano com'erano.

def sezione(titolo)
  puts
  puts "=" * 66
  puts titolo
  puts "=" * 66
end

def irb(codice)
  puts "irb> #{codice}"
  risultato = eval(codice, TOPLEVEL_BINDING)
  puts "=> #{risultato.inspect}"
rescue StandardError => e
  puts "!! #{e.class}: #{e.message}"
end

# Mostra l'SQL che Active Record genera (nella console di Rails compare da solo).
# Ho tolto le righe di transazione/savepoint, che qui sono dovute al rollback finale.
def con_sql
  precedente = ActiveRecord::Base.logger
  logger = Logger.new($stdout)
  logger.formatter = proc do |_, _, _, msg|
    riga = msg.to_s.gsub(/\e\[[0-9;]*m/, "").strip
    riga.match?(/SAVEPOINT|transaction/i) ? "" : "   SQL> #{riga}\n"
  end
  ActiveRecord::Base.logger = logger
  yield
ensure
  ActiveRecord::Base.logger = precedente
end

articoli_prima = Article.count
id_massimo_prima = Article.maximum(:id)
puts "Articoli nel database prima degli esercizi: #{articoli_prima}"

ActiveRecord::Base.transaction do
  # -------------------------------------------------------------------------
  sezione "ACTIVE RECORD: tabelle ↔ classi, righe ↔ oggetti, colonne ↔ attributi"
  irb "Article.superclass"
  irb "Article.superclass.superclass"
  irb "Article.table_name"
  irb "Article.primary_key"

  sezione "LE CONVENZIONI: nome classe singolare ↔ nome tabella plurale"
  irb '"Event".tableize'
  irb '"Person".tableize'            # plurale irregolare: people
  irb '"Category".tableize'
  irb '"OrderItem".tableize'         # CamelCase → snake_case plurale
  irb '"order_items".classify'       # e il percorso inverso
  irb '"people".classify'

  # -------------------------------------------------------------------------
  sezione "LA CONSOLE: esplorare il modello"
  irb "Article.column_names"
  irb "Article"                      # solo il nome della classe: mostra anche i tipi
  irb "Article.columns_hash['title'].type"
  irb "Article.methods.size > 400"   # il libro dice 690: varia con la versione

  # -------------------------------------------------------------------------
  sezione "CREARE: new + writer + save"
  irb "article = Article.new"
  irb "article.new_record?"          # true: non è ancora nel database
  irb "article.attributes"
  irb "article.title = 'RailsConf'"
  irb "article.body = 'RailsConf is the official gathering for Rails developers..'"
  irb "article.published_at = '2020-01-31'"
  irb "article.id"                   # nil: ancora niente id
  puts "--- save: ecco l'SQL generato"
  con_sql { irb "article.save" }
  irb "article.new_record?"          # false: ora è salvato
  irb "article.id.nil?"              # false: ha un id
  irb "Article.count == #{articoli_prima} + 1"

  puts
  puts "--- Un writer è un metodo travestito: article.title = 'x'  equivale a  article.title=('x')"
  irb "article.title=('RailsConf (via metodo)')"
  irb "article.title"

  sezione "CREARE: new passando tutti gli attributi insieme"
  irb "article = Article.new(title: 'Introduction to Active Record', body: 'Active Record is Rails default ORM..', published_at: Time.zone.now)"
  irb "article.save"

  sezione "CREARE: create = new + save in un colpo solo"
  irb "Article.create(title: 'RubyConf 2020', body: 'The annual RubyConf will take place in..', published_at: '2020-01-31')"
  irb "attributes = {title: 'Rails Pub Nite', body: 'Rails Pub Nite is every 3rd Monday of each month.', published_at: '2020-01-31'}"
  irb "Article.create(attributes)"
  irb "Article.count == #{articoli_prima} + 4"

  # -------------------------------------------------------------------------
  sezione "LEGGERE: find per id"
  irb "terzo = Article.where(title: 'Introduction to Active Record').first"
  irb "Article.find(terzo.id).title"
  irb "terzo.id == Article.find(terzo.id).id"
  irb "Article.find(1037)"           # non esiste: solleva RecordNotFound

  puts "--- Come recuperare con eleganza da un RecordNotFound (begin/rescue):"
  begin
    Article.find(1037)
  rescue ActiveRecord::RecordNotFound
    puts "We couldn't find that record"
  end
  irb "Article.find_by(id: 1037)"    # alternativa che restituisce nil invece di sollevare
  irb "Article.find([terzo.id, Article.last.id]).map(&:title)"   # array di id → array di record

  sezione "LEGGERE: first, last, all"
  irb "Article.first.class.name"
  irb "Article.last.title"
  irb "Article.all.class"            # una Relation, non un semplice array
  irb "articles = Article.limit(2)"
  irb "articles.size"
  irb "articles[0].class.name"
  irb "articles.first.title == articles[0].title"
  irb "Article.all.map(&:id).size == Article.count"
  puts "--- each: stampa i titoli (i primi 3 di #{Article.count})"
  Article.all.first(3).each { |a| puts a.title }

  sezione "LEGGERE: ordinare con order"
  irb "Article.order(:title).pluck(:title)"
  irb "Article.order(published_at: :desc).pluck(:title)"
  irb "Article.order(:title).class"  # ancora una Relation: concatenabile
  irb "Article.order(:title).limit(2).pluck(:title)"
  puts "--- Lazy loading: costruire la query non la esegue. Questo è l'SQL che verrà usato:"
  irb "Article.order(:title).limit(2).to_sql"

  sezione "LEGGERE: condizioni con where"
  irb "Article.where(title: 'RailsConf').first.title"
  irb "Article.where(title: 'RailsConf').all.class"
  irb "Article.where(title: 'RailsConf').count"
  irb "Article.where(title: 'Unknown').all.to_a"   # nessun risultato: array vuoto, niente errore
  irb "Article.where(title: 'Unknown').first"      # first su una Relation vuota: nil

  # -------------------------------------------------------------------------
  sezione "AGGIORNARE: trova, modifica, salva"
  irb "article = Article.where(title: 'RailsConf').first"
  irb "article.title = 'Rails 6 is great'"
  irb "article.published_at = Time.zone.now"
  puts "--- save: ecco l'UPDATE"
  con_sql { irb "article.save" }
  irb "Article.find(article.id).title"

  puts
  puts "--- update: modifica e salva in un colpo solo (metodo di ISTANZA)"
  irb "article = Article.find(article.id)"
  irb "article.update(title: 'RailsConf2020', published_at: 1.day.ago)"
  irb "Article.find(article.id).title"
  puts "(Il libro usa update_attributes: in Rails 6.0 è deprecato e in 6.1 è stato rimosso. Si usa update.)"

  # -------------------------------------------------------------------------
  sezione "ELIMINARE: destroy (istanza)"
  irb "article = Article.last"
  irb "titolo_eliminato = article.title"
  puts "--- destroy: ecco il DELETE"
  con_sql { irb "article.destroy" }
  irb "article.destroyed?"
  irb "article.frozen?"              # l'oggetto resta in memoria ma è "congelato"
  irb "article.title"                # leggere si può
  irb "article.location = 'Toronto, ON'"   # modificare no
  irb "Article.where(title: titolo_eliminato).count"

  sezione "ELIMINARE: destroy come metodo di CLASSE (trova ed elimina)"
  irb "id_a = Article.first.id"
  irb "Article.destroy(id_a).class.name"
  irb "ids = Article.limit(2).pluck(:id)"
  irb "Article.destroy(ids).size"

  sezione "ELIMINARE: delete (senza istanziare, senza callback)"
  irb "Article.create!(title: 'Da eliminare', body: 'x').id.class"
  irb "id_b = Article.last.id"
  irb "Article.delete(id_b)"         # numero di righe eliminate: 1
  irb "Article.delete([id_b, id_b + 1])"   # non esistono più: 0
  irb "Article.delete(1, 2, 3)"      # delete vuole un array esplicito
  irb "Article.create!(title: 'Vecchio', body: 'x', published_at: '2010-06-01').id.class"
  irb "Article.delete_by(\"published_at < '2011-01-01'\")"   # elimina per condizione, restituisce il numero

  # -------------------------------------------------------------------------
  sezione "QUANDO I BUONI MODELLI SI COMPORTANO MALE: errori di validazione"
  irb "article = Article.new"
  irb "article.errors.any?"          # false: le validazioni non sono ancora scattate!
  irb "article.save"                 # false: non salva
  irb "article.errors.any?"
  irb "article.errors.full_messages" # (nel blog sono in italiano, nel libro in inglese)
  irb "article.errors.messages[:title]"
  irb "article.errors.size"
  irb "article.valid?"               # valida senza salvare
  irb "article.title = 'Ciao'; article.body = 'Testo'; article.valid?"
  irb "article.errors.any?"

  raise ActiveRecord::Rollback       # annulla TUTTO quello fatto sopra
end

# ---------------------------------------------------------------------------
sezione "VERIFICA: il database è com'era prima?"
puts "Articoli prima:  #{articoli_prima}"
puts "Articoli dopo:   #{Article.count}"
puts "Id massimo prima/dopo: #{id_massimo_prima} / #{Article.maximum(:id)}"
puts(Article.count == articoli_prima ? "OK: il rollback ha annullato tutto." : "ATTENZIONE: il database è cambiato!")
