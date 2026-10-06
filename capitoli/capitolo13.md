# Capitolo 13 — Active Job: lavori in background

> **In una frase**: **Active Job** permette di rimandare un'operazione lenta (come spedire un'email) a un "lavoratore" in background, così la risposta all'utente parte subito; nel blog ora tutte le email vanno in coda con `deliver_later`.

## 1. Il contesto (la mappa mentale)

L'immagine del libro: all'ufficio postale **non** ti si chiede di restare allo sportello finché il pacco non è arrivato; ti basta sapere che la consegna è *pianificata*.

```
SENZA coda (deliver_now)                       CON coda (deliver_later)
 browser ─► richiesta ─► [spedisci email 2 s]    browser ─► richiesta ─► accoda il job (ms) ─► risposta SUBITO
                         ─► risposta dopo 2 s                              │
                                                                           ▼  (in background, un altro thread/processo)
                                                                      worker: esegue il job ─► email consegnata
```

| Concetto | Cosa è |
|---|---|
| **Job** | una classe (in `app/jobs/`) con un metodo `perform`: il lavoro da fare |
| **Coda** (*queue*) | la lista dei job in attesa; ha un nome (`default`, `mailers`, `critical`…) |
| **Adattatore** (*queue adapter*) | chi la gestisce davvero: `:async`, `:inline`, `:test`, oppure Sidekiq, Resque, Delayed::Job… |
| **Worker** | chi pesca i job dalla coda e li esegue |

Active Job è uno **strato comune**: il codice dei job non cambia se domani passi da un backend all'altro.

## 2. Cosa ho fatto

| Cosa | Dove |
|---|---|
| Job didattico (indovina un numero) con `retry_on` e `discard_on` | `app/jobs/guess_a_number_between_one_and_ten_job.rb` |
| Invio email in background (3 punti) | `notify_friend` nel controller, `Comment#email_article_author`, `DraftArticlesMailbox#process` → `deliver_later` |
| `after_create` → **`after_create_commit`** | `app/models/comment.rb` (vedi 3.5) |
| Job di consegna che **scarta** se il record è sparito | `app/jobs/application_mail_delivery_job.rb` + `ApplicationMailer` |
| `discard_on ActiveJob::DeserializationError` per tutti i job | `app/jobs/application_job.rb` |
| Test (216 totali, 10 nuovi) | `test/jobs/…`, `test/models/comment_test.rb`, `test/controllers/articles_controller_test.rb` |
| Prove | [capitolo13_esercizi.rb](capitolo13_esercizi.rb) |

### Dove ho deviato dal libro (e perché)

| Cosa | Libro | Qui | Motivo |
|---|---|---|---|
| Job didattico | messaggi in inglese, un file per ogni listato (13-1, 13-2, 13-3) | il **listato finale** (13-3), commentato in italiano | si studia la versione completa |
| Job di consegna delle email | quello di Rails (`ActionMailer::MailDeliveryJob`) | `ApplicationMailDeliveryJob` che aggiunge `discard_on DeserializationError` | in Rails 6.0 quel job **non** eredita da `ApplicationJob`: se il commento viene eliminato prima dell'invio, il job fallirebbe (con un backend vero, riprovando all'infinito) |
| Callback del commento | `after_create` | **`after_create_commit`** | `after_create` scatta *dentro* la transazione: un job veloce potrebbe non trovare ancora la riga |
| Test delle email | nessuno | `assert_enqueued_emails`, `perform_enqueued_jobs`, `deliveries.clear` a ogni test | verificare che la risposta **non** consegni nulla e che il job lo faccia poi |
| Adattatore | `:async` | `:async` in sviluppo, `:test` nei test, **da cambiare in produzione** | `:async` perde i job se il server si riavvia |
| Benchmark | form reale, 2 s → 40 ms | server di posta lento **simulato** (1 s): `deliver_now` 1135 ms, `deliver_later` 6 ms | niente server SMTP vero |

## 3. I concetti chiave

### 3.1 Configurare Active Job: gli adattatori

Non serve configurare nulla: c'è già (lo usano Active Storage e Action Mailbox: nel log cerca `[ActiveJob]`). Si sceglie l'adattatore con `config.active_job.queue_adapter`:

| Adattatore | Comportamento | Dove si usa |
|---|---|---|
| **`:async`** (default) | un pool di *thread* dentro lo stesso processo Rails | sviluppo. ⚠️ in memoria: se il server si ferma, **i job in attesa si perdono** |
| **`:inline`** | esegue il job **subito**, dentro la richiesta | script e rake task; si perde ogni vantaggio |
| **`:test`** | non esegue: **tiene** i job in una lista | test (è già attivo) |
| `:sidekiq`, `:resque`, `:delayed_job`… | un sistema esterno (con Redis o database) che conserva i job, li riprova, ha una dashboard | **produzione** |

Verificato: i job passano da thread diversi (thread della richiesta ≠ thread del job).

### 3.2 Anatomia di un job

```ruby
class GuessANumberBetweenOneAndTenJob < ApplicationJob   # eredita da ApplicationJob < ActiveJob::Base
  queue_as :default                                      # in che coda va
  class ThatsNotFair < StandardError; end                # eccezioni su misura (una riga)
  class GuessedWrongNumber < StandardError; end

  discard_on ThatsNotFair                                # → si SCARTA
  retry_on GuessedWrongNumber, attempts: 8, wait: 1      # → si RIPROVA (max 8, ogni 1 s)

  def perform(my_number)                                 # obbligatorio: il lavoro
    raise ThatsNotFair, "…" unless my_number.is_a?(Integer) && my_number.between?(1, 10)
    raise GuessedWrongNumber, "…" unless rand(1..10) == my_number
  end
end
```

| Comando | Cosa fa |
|---|---|
| `Job.new.perform(3)` | **un normale metodo**: si esegue subito, **ignorando** retry/discard (l'eccezione esce) |
| `Job.perform_now(3)` | esegue subito **con** le regole del job (callback, retry, discard) |
| `Job.perform_later(3)` | **accoda**: il worker lo eseguirà dopo (`Enqueued…` poi `Performing…` nel log) |
| `Job.set(wait: 5.minutes).perform_later(3)` | accoda per tra 5 minuti (verificato: `at` = +300 s) |
| `Job.set(wait_until: Date.tomorrow.noon)…` | accoda per un momento preciso |
| `Job.set(queue: :critical)…` | su un'altra coda (verificato: `queue_name` → `"critical"`) |

### 3.3 `retry_on` e `discard_on`

| | Quando | Effetto |
|---|---|---|
| **`retry_on E, attempts: n, wait: s`** | l'errore è **temporaneo** (API esterna giù, database occupato) | il job si **riaccoda** dopo `s` secondi, fino a `n` tentativi; dopo l'ultimo l'eccezione **esce** |
| **`discard_on E`** | il job **non ha più senso** (il record è stato eliminato, l'argomento è invalido) | si **scarta** in silenzio; il log dice `Discarded … due to …` |

Verificato con lo script: il numero 3 contro un `rand` forzato a 5 → **7 riaccodamenti** (`Retrying … in 1 seconds`) e all'8° tentativo `Stopped retrying … which reoccurred on 8 attempts` con l'eccezione che esce; `perform_now(11)` → `Discarded`, nessuna eccezione. Default: 5 tentativi e 3 secondi.

⚠️ In Rails 6.0 il conteggio dei tentativi è **per tipo di eccezione**.

### 3.4 Cosa si può passare a un job: la serializzazione

Il job può girare ore dopo, in un altro processo: gli argomenti diventano **JSON**.

| Argomento | Diventa |
|---|---|
| numeri, stringhe, booleani, `nil`, array, hash, simboli, date | se stessi (i simboli con un marcatore) |
| un **record** Active Record | un **GlobalID**: `{"_aj_globalid"=>"gid://blog/Article/5"}` |
| qualsiasi altro oggetto (`Object.new`, un `Proc`) | ❌ `ActiveJob::SerializationError: Unsupported argument type: Object` |

Conseguenze (importanti):

1. Si passa il **record**, non una copia dei suoi dati: il job lo **ricarica dal database** quando parte e vede i dati **aggiornati**.
2. Se nel frattempo il record è stato eliminato → `ActiveJob::DeserializationError`. Per questo `discard_on ActiveJob::DeserializationError`.
3. Mai passare oggetti grandi o segreti (la coda li conserva).

### 3.5 Le email con `deliver_later`

```ruby
NotifierMailer.email_friend(@article, nome, email).deliver_later    # prima: deliver_now
```

Cosa finisce nella coda (verificato): un job `ApplicationMailDeliveryJob`, coda **`mailers`**, con gli argomenti `["NotifierMailer", "email_friend", "deliver_now", …]`: il **nome** del mailer e del metodo, **non** l'email già pronta. Il messaggio si costruisce solo quando il job gira.

**Quanto si guadagna** (server di posta lento simulato, 1 secondo): `deliver_now` **1135 ms**, `deliver_later` **6 ms**. Nel libro: da ~2 s a ~40 ms.

Tre punti convertiti: il form "invia a un amico", l'avviso all'autore per un commento, la conferma della bozza ricevuta per email.

**Perché `after_create_commit`.** Una trappola da conoscere:

```
after_create (DENTRO la transazione)               after_create_commit (DOPO il COMMIT)
 BEGIN                                               BEGIN
  INSERT comment                                      INSERT comment
  after_create → accoda il job ──► il worker parte    COMMIT   ← ora il commento esiste per tutti
                 e fa Comment.find(id)  ✗ non c'è!    after_commit → accoda il job ──► worker: find ✓
 COMMIT
```

Con l'adattatore `:async` (un altro thread) un job veloce può partire **prima del commit** e non trovare il commento. Con `after_create_commit` il job parte sempre dopo.

**Se il record sparisce** prima dell'invio (commento eliminato), `ApplicationMailDeliveryJob` scarta il job: verificato → nessuna eccezione e nessuna email. Senza `discard_on` il test **fallisce** (verificato togliendolo per prova).

⚠️ Con `deliver_later` **la richiesta non sa più se l'email è stata consegnata**: il messaggio "Messaggio inviato" significa "messaggio *messo in coda*". Gli errori compaiono nel log del job, non all'utente.

## 4. Trappole e scoperte

| Cosa | Spiegazione |
|---|---|
| `assert_emails` e `deliveries` nei test | con `deliver_later` nel test adapter **non** si consegna nulla da soli: serve `perform_enqueued_jobs { … }` (oppure `assert_enqueued_emails` per verificare solo l'accodamento) |
| Email "vecchie" nei test | `ActionMailer::Base.deliveries` **non** si svuota da solo tra un test e l'altro (solo nei `ActionMailer::TestCase`): `.last` poteva leggere l'email di un altro test. Ora `setup { deliveries.clear }` in `test_helper` |
| `perform_enqueued_jobs` e job con record eliminati | l'helper di Rails **istanzia** i job per filtrarli e solleva `DeserializationError` prima di eseguirli: per provare lo scarto si usa `ActiveJob::Base.execute(…)` a mano |
| Provare `retry_on` nei test | `rand` è casuale: si **sostituisce** (`stub` di `minitest/mock`) con un valore fisso. Dopo 8 tentativi (e non 5, il default) l'eccezione esce |
| `perform` diretto e regole | `Job.new.perform(11)` solleva `ThatsNotFair`; `Job.perform_now(11)` no (lo assorbe `discard_on`) |
| `:inline` negli script | gli script che creano dati usano `:inline`: `deliver_later` diventa subito una consegna |
| SQLite e job in parallelo | `:async` + SQLite = più thread che scrivono: già ora `timeout: 15000` in `database.yml`. In produzione si usa un database vero |
| Il job di Action Mailbox | `bounce_with` usa già `deliver_later` per rispondere ai rimbalzi (da Rails 6.0) |
| Lo script `capitolo12_esercizi.rb` | usa `:inline`: `deliver_later` consegna subito, quindi funziona uguale |

## 5. Come provarlo

```bash
bin/rails console
# > GuessANumberBetweenOneAndTenJob.perform_later(3)        # guarda l'output: Enqueued / Performing / Performed
# > GuessANumberBetweenOneAndTenJob.perform_later(11)       # → Discarded
bin/rails server      # poi invia un articolo a un amico: nel log, [ActiveJob] Enqueued → risposta → Performing
bin/rails test        # 216 test
PATH="$HOME/.local/bin:$PATH" bin/rails runner capitoli/capitolo13_esercizi.rb
```

## 6. Checklist del capitolo

- [x] Capire che cos'è un job e perché serve (richiesta veloce)
- [x] Adattatori: `:async`, `:inline`, `:test`, e quelli di produzione
- [x] `rails g job`, `ApplicationJob`, `queue_as`, `perform`
- [x] `perform_now` e `perform_later` (e `set(wait:)`)
- [x] `retry_on` e `discard_on`
- [x] Convertire le consegne in `deliver_later` (controller, modello, mailbox)
- [x] Misurare la differenza di tempo
- [x] 216 test; script con le prove

## 7. Auto-verifica

1. Perché una richiesta che impiega 2 secondi è un problema anche se "funziona"?
2. Che differenza c'è tra `perform`, `perform_now` e `perform_later`?
3. Perché `:async` va bene in sviluppo ma non in produzione?
4. Quando si usa `retry_on` e quando `discard_on`?
5. Che cosa succede al `Comment` passato a un job, e perché a volte serve `discard_on ActiveJob::DeserializationError`?
6. Perché il callback del commento è `after_create_commit`?
7. Dopo `deliver_later`, il messaggio "Messaggio inviato" è ancora del tutto veritiero?

<details><summary>Risposte</summary>

1. Il server può gestire solo un certo numero di richieste alla volta: se ciascuna aspetta 2 s, la coda degli utenti si allunga e servono più server. L'utente poi aspetta senza motivo.
2. `perform` è il metodo che fa il lavoro (chiamato direttamente ignora le regole del job); `perform_now` esegue subito con callback, retry e discard; `perform_later` mette il job in **coda** e lo esegue un worker in background.
3. Tiene la coda in memoria: se il processo si ferma o si riavvia, i job in attesa spariscono. In produzione serve un backend che li conservi (Sidekiq, Resque…).
4. `retry_on` per errori **temporanei** (un servizio esterno non risponde); `discard_on` quando il job **non ha più senso** (record eliminato, argomento non valido).
5. Viene serializzato come GlobalID e **ricaricato dal database** quando il job parte. Se nel frattempo è stato eliminato, il caricamento fallisce con `DeserializationError`: conviene scartare il job.
6. `after_create` scatta prima del commit della transazione: un job veloce in un altro thread potrebbe non trovare ancora il commento. `after_create_commit` parte dopo il commit.
7. Non del tutto: significa che il messaggio è stato **messo in coda**. Un errore di consegna comparirà solo nel log del job.

</details>

---

**Prossimo capitolo**: il **14** tratta **Active Model**: usare validazioni e callback anche su classi **senza tabella**, per rendere robusto il form "invia a un amico" (nome e email vengono ora controllati "a mano" nel controller).
