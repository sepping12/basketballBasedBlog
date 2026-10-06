# Capitolo 13 — Active Job: lavori in background. Gli esempi, eseguibili.
#
# Esegui con:   PATH="$HOME/.local/bin:$PATH" bin/rails runner capitoli/capitolo13_esercizi.rb
#
# Lo script non lascia tracce: i commenti che crea li elimina nel blocco `ensure`, e le email vanno in
# ActionMailer::Base.deliveries (delivery_method :test), non escono dal computer.
# Un errore stampato con "!!" è INTENZIONALE (lo spiega il commento sopra).

require "stringio"

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

# I messaggi di Active Job ("Enqueued…", "Performing…") vanno nel log: per vederli qui li copio su un buffer.
LOG = StringIO.new
ActiveJob::Base.logger = Logger.new(LOG).tap { |l| l.formatter = proc { |_s, _t, _p, msg| "#{msg}\n" } }
def mostra_log
  LOG.string.lines.map { |riga| riga.gsub(/\e\[[0-9;]*m/, "").strip }.reject { |riga| riga.empty? || riga =~ /\A(\/|\(eval\)|capitoli\/|bin\/)/ }.each { |riga| puts "   [log] #{riga[0, 150]}" }
  LOG.truncate(0)
  LOG.rewind
end

ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.deliveries.clear
ActiveJob::Base.queue_adapter = :inline            # se non diversamente indicato, i job girano subito
Job = GuessANumberBetweenOneAndTenJob
commenti_creati = []

begin
  sezione "1. Il job didattico: perform e perform_later"
  puts "Un job è una classe con un metodo `perform`. Si può eseguire SUBITO (new.perform) o PIÙ TARDI (perform_later)."
  irb "Job.ancestors.first(3)"
  irb "Job.queue_name"
  irb "Job.new.perform(11)"                        # !! ThatsNotFair: perform diretto NON passa dalle regole retry/discard
  puts "\nSolo un numero tra 1 e 10 è valido. perform diretto = un normale metodo: l'eccezione esce."
  irb "Job.perform_now(11)"                         # perform_now = con le regole del job: discard_on la assorbe
  mostra_log
  puts "\n→ perform_now applica discard_on: il job viene SCARTATO, nessuna eccezione. Il log lo dice (Discarded)."

  sezione "2. retry_on: riprovare quando il job fallisce (adattatore :test, per ispezionare la coda)"
  ActiveJob::Base.queue_adapter = :test
  adapter = ActiveJob::Base.queue_adapter
  adapter.enqueued_jobs.clear
  $job = Job.new(3)
  condividi :adapter, adapter
  # rand è casuale: per l'esempio lo forzo a 5, così il numero 3 è SEMPRE sbagliato.
  $job.define_singleton_method(:rand) { |*| 5 }
  irb "$job.perform_now"
  mostra_log
  irb "adapter.enqueued_jobs.size"
  irb "adapter.enqueued_jobs.first.slice(:job, :args, :queue)"
  irb "(adapter.enqueued_jobs.first[:at] - Time.now.to_f).round(1)"
  puts "\n→ ogni tentativo fallito RIACCODA il job tra 1 secondo (wait: 1), fino a 8 tentativi (attempts: 8)."
  puts "  Dopo l'ottavo si arrende e l'eccezione esce. Sette tentativi:"
  6.times { $job.perform_now }
  irb "adapter.enqueued_jobs.size"
  irb "$job.perform_now"                             # !! l'8° tentativo: nessun altro retry, l'eccezione esce
  mostra_log

  sezione "3. Cosa viaggia nella coda: la SERIALIZZAZIONE degli argomenti"
  puts "Il job può girare ore dopo, in un altro processo: gli argomenti diventano testo (JSON)."
  articolo = Article.published.first
  condividi :articolo, articolo
  irb "ActiveJob::Arguments.serialize([articolo, 'ciao', 5, { chiave: :valore }])"
  puts "\n→ un record Active Record diventa un GlobalID (gid://blog/Article/ID): il job lo ricarica dal DB quando parte."
  puts "  Conseguenza: vede i dati AGGIORNATI, e se il record è stato eliminato nel frattempo → DeserializationError."
  irb "ActiveJob::Arguments.serialize([Object.new])"          # !! SerializationError: un oggetto qualsiasi non è serializzabile
  irb "ActiveJob::Arguments.serialize([Proc.new {}])"         # !! idem per i blocchi

  sezione "4. Pianificare nel futuro e scegliere la coda"
  adapter.enqueued_jobs.clear
  irb "Job.set(wait: 5.minutes).perform_later(4).class"
  irb "(adapter.enqueued_jobs.last[:at] - Time.now.to_f).round"
  irb "Job.set(wait_until: Date.tomorrow.noon).perform_later(4).class"
  irb "Job.set(queue: :critical).perform_later(4).queue_name"
  irb "adapter.enqueued_jobs.map { |j| j[:queue] }"
  adapter.enqueued_jobs.clear
  mostra_log

  sezione "5. deliver_later: l'email diventa un job (ActionMailer::MailDeliveryJob → il nostro ApplicationMailDeliveryJob)"
  irb "NotifierMailer.delivery_job"
  irb "NotifierMailer.email_friend(articolo, 'Marco', 'amico@example.com').deliver_later.class"
  irb "adapter.enqueued_jobs.first.slice(:job, :queue)"
  irb "adapter.enqueued_jobs.first[:args].first(3)"
  irb "ActionMailer::Base.deliveries.size"
  puts "\n→ nella coda ci sono i NOMI (mailer, metodo, 'deliver_now') e gli argomenti: l'email NON è ancora stata costruita."
  adapter.enqueued_jobs.clear

  sezione "6. Quanto si guadagna? Un server di posta LENTO (1 secondo) simulato"
  class ConsegnaLenta
    def initialize(_opzioni = {}); end
    def deliver!(mail); sleep 1; ActionMailer::Base.deliveries << mail; end
  end
  ActionMailer::Base.add_delivery_method :lenta, ConsegnaLenta
  ActionMailer::Base.delivery_method = :lenta
  ActionController::Base.allow_forgery_protection = false    # (nello script non c'è il token CSRF del form)
  sessione = ActionDispatch::Integration::Session.new(Rails.application)
  sessione.host! "localhost"
  condividi :sessione, sessione
  condividi :url, "/articles/#{articolo.id}/notify_friend"

  def tempo_richiesta(adapter_nome, metodo_consegna)
    ActiveJob::Base.queue_adapter = adapter_nome
    inizio = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    mail = NotifierMailer.email_friend(Article.published.first, "Marco", "amico@example.com")
    mail.public_send(metodo_consegna)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - inizio) * 1000).round
  end

  ms_now = tempo_richiesta(:inline, :deliver_now)
  puts "deliver_now   → il chiamante aspetta la consegna:   #{ms_now} ms"
  ms_later = tempo_richiesta(:test, :deliver_later)
  puts "deliver_later → il chiamante aspetta solo l'accodamento: #{ms_later} ms"
  ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  puts "(Dentro un controller è lo stesso: la richiesta HTTP risponde subito e l'invio avviene dopo.)"

  puts "\nIl vero adattatore :async (predefinito di Rails): il job gira in un ALTRO THREAD, fuori dalla richiesta."
  ActiveJob::Base.queue_adapter = :async
  # (Un argomento come una Queue non è serializzabile: per l'esempio il job scrive su una variabile globale.)
  $fili = Queue.new
  class ThreadJob < ApplicationJob
    def perform; $fili << Thread.current.object_id; end
  end
  principale = Thread.current.object_id
  ThreadJob.perform_later
  altro = $fili.pop
  puts "   thread della richiesta: #{principale}   thread del job: #{altro}   (diversi? #{principale != altro})"

  LOG.truncate(0); LOG.rewind
  sezione "7. Il callback del commento: after_create_commit e il job"
  ActionMailer::Base.delivery_method = :test
  ActiveJob::Base.queue_adapter = :inline
  ActionMailer::Base.deliveries.clear
  condividi :articolo, articolo
  irb "c = articolo.comments.create!(name: 'Dude', email: 'dude@example.com', body: 'Bella!'); commenti = [c]; c.persisted?"
  commenti_creati.concat(articolo.comments.where(name: "Dude").to_a)
  mostra_log
  irb "ActionMailer::Base.deliveries.size"
  irb "ActionMailer::Base.deliveries.last.subject"
  irb "ActionMailer::Base.deliveries.last.to"
  puts "\nPerché `after_create_commit` e non `after_create`? after_create gira DENTRO la transazione, prima del COMMIT:"
  puts "un job veloce (adattatore :async, un altro thread) potrebbe cercare il commento quando nel DB non c'è ancora."
  puts "after_create_commit parte DOPO il commit: il job lo trova sempre."
  puts "\nE se il commento viene eliminato prima che il job giri? (ApplicationMailDeliveryJob lo scarta)"
  ActiveJob::Base.queue_adapter = :test
  ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  ActionMailer::Base.deliveries.clear
  c2 = articolo.comments.create!(name: "Dude", email: "dude@example.com", body: "Scompare")
  c2.destroy
  dati = ActiveJob::Base.queue_adapter.enqueued_jobs.first
  condividi :dati, dati
  irb %(ActiveJob::Base.execute("job_class" => dati[:job].to_s, "job_id" => SecureRandom.uuid, "queue_name" => dati[:queue], "arguments" => dati[:args], "executions" => 0, "locale" => "it", "timezone" => "UTC"))
  mostra_log
  irb "ActionMailer::Base.deliveries.size"
  puts "→ nessuna eccezione, nessuna email: il job è stato scartato (Discarded … DeserializationError)."

  sezione "8. Il blog dopo il capitolo"
  puts "deliver_later in 3 punti: ArticlesController#notify_friend, Comment#email_article_author, DraftArticlesMailbox#process."
  irb "[Article.count, Comment.count, ActionMailer::Base.deliveries.size]"
ensure
  # Pulizia: i commenti creati dallo script (anche quelli non tracciati) e le email.
  Comment.where(name: "Dude", email: "dude@example.com").destroy_all
  ActiveJob::Base.queue_adapter = :inline
  puts
  puts "(pulizia fatta — commenti rimasti: #{Comment.count})"
end
