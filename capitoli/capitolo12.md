# Capitolo 12 — Inviare e ricevere email

> **In una frase**: **Action Mailer** crea e invia email (come un controller produce pagine, con template in HTML e in testo); **Action Mailbox** fa il contrario: riceve email e le trasforma in azioni. Nel blog: l'autore riceve un'email quando arriva un commento, un lettore può consigliare un articolo a un amico, e l'autore può creare una **bozza scrivendo un'email**.

## 1. Il contesto (la mappa mentale)

```
 INVIO (Action Mailer)                                            RICEZIONE (Action Mailbox)
 ┌────────────┐   NotifierMailer.comment_added(c)                ┌────────────────────┐
 │ controller │──►  mailer = "controller per le email"           │ email in arrivo     │
 │ o callback │      │ variabili @… + template .html/.text       │ a <token>@drafts…   │
 └────────────┘      ▼                                           └─────────┬──────────┘
              Mail::Message (testo + HTML + allegati)                       ▼  (servizio di posta → "ingress")
                     │  deliver_now                              ActionMailbox::InboundEmail  (riga nel DB + file)
                     ▼                                                      │  router: "@drafts." → :draft_articles
              metodo di consegna: SMTP / file / test                        ▼
              (sviluppo qui: file in tmp/mails)                  DraftArticlesMailbox#process
                                                                  → crea la bozza, risponde con una conferma
```

| Concetto | Equivalente che già conosci |
|---|---|
| **Mailer** (`NotifierMailer`) | un **controller**; i suoi metodi sono "azioni" che producono un messaggio |
| **Template** del mailer (`.html.erb`, `.text.erb`) | le **viste**; il layout `mailer` è come `application` |
| **`mail(to:, subject:)`** | `render` |
| **Mailbox** (`DraftArticlesMailbox`) | un controller **per le email in arrivo** |
| **`routing`** in `ApplicationMailbox` | `routes.rb` |

> 🔄 **Aggiornamento (Capitolo 13)**: dove qui si legge `deliver_now`, il codice ora usa **`deliver_later`** (le email partono da un job in background) e il callback del commento è `after_create_commit`. Il messaggio "Messaggio inviato" vuol dire "messo in coda". Vedi [capitolo13.md](capitolo13.md).

## 2. Cosa ho fatto

### Invio (Action Mailer)

| Cosa | Dove |
|---|---|
| Credenziali SMTP **segnaposto** (cifrate) | `bin/rails credentials:edit` → `config/credentials.yml.enc` |
| Configurazione per ambiente | `development.rb` (SMTP *oppure* file), `test.rb`, `production.rb` (`default_url_options`) |
| Mailer e template (HTML + testo) | `NotifierMailer` con `email_friend` e `comment_added`; layout `mailer.html.erb` / `.text.erb` |
| "Invia a un amico" | route `member` `notify_friend`, azione nel controller, riquadro `<details>` nella pagina articolo |
| Allegato | la copertina (Active Storage `download`) |
| Avviso all'autore per i commenti | il callback `after_create` di `Comment` ora invia l'email |
| Anteprime | `test/mailers/previews/` → <http://localhost:3000/rails/mailers> |

### Ricezione (Action Mailbox)

| Cosa | Dove |
|---|---|
| Installazione | `bin/rails action_mailbox:install` + `db:migrate` (tabella `action_mailbox_inbound_emails`) |
| Indirizzo segreto per ogni autore | colonna `users.draft_article_token` (indice **unico**) + `has_secure_token` + `User#draft_article_email` |
| La mailbox | `DraftArticlesMailbox` (+ `DraftArticlesMailer` per le risposte) |
| Instradamento | `ApplicationMailbox`: `routing /@<dominio>\z/i => :draft_articles` |
| Mostrare l'indirizzo all'autore | pagina "Scrivi" e pagina "Il mio account" (con "Genera un nuovo indirizzo") |
| Test | **206** (56 nuovi) |
| Prove | [capitolo12_esercizi.rb](capitolo12_esercizi.rb) |

### Dove ho deviato dal libro (e perché)

| Cosa | Libro | Qui | Motivo |
|---|---|---|---|
| Consegna in sviluppo | SMTP di Gmail con credenziali vere | **file** in `tmp/mails/`, e SMTP solo se le credenziali non sono segnaposto | niente account da configurare; nessuna email esce per sbaglio |
| `raise_delivery_errors` | `false` (poi `true` per il debug) | `true` | nasconderebbe i problemi di invio |
| `.deliver` | sì | **`.deliver_now`** | è il nome esplicito; `deliver_later` arriva nel Capitolo 13 |
| Form "invia a un amico" | `onclick` con JavaScript inline per aprirlo | elemento HTML **`<details>`** | nessun JavaScript, accessibile, e funziona sempre |
| Validazione del form | nessuna | nome obbligatorio (≤ 60, **senza a-capo**), email valida (≤ 254), solo articoli **pubblicati** | evita email a indirizzi falsi e l'iniezione di intestazioni (vedi sotto) |
| Bozze | visibili a tutti ("dovremmo cambiarlo") | **solo all'autore**; per gli altri 404 (`Article.visible_to`) | una bozza arrivata per email non deve essere pubblica |
| Dominio delle bozze | `drafts.example.com` fisso | **`config.x.drafts_domain`** (variabile `DRAFTS_DOMAIN`) | cambiabile senza toccare il codice |
| Testo dell'email → articolo | `mail.body` così com'è | **conversione** in paragrafi HTML (`PlainText.to_html`) e scelta della parte giusta (testo / HTML / multipart) | l'articolo è un rich text (Capitolo 11); `mail.body` è un oggetto, non il testo |
| Articolo non valido | `create!` (l'elaborazione fallisce) | `save` e **risposta al mittente** con il motivo | l'autore non resta senza spiegazioni |
| Token degli utenti esistenti | a mano dalla console | **nella migrazione** | non si dimentica |
| Rigenerare il token | solo da console | pulsante nel proprio account | se l'indirizzo viene condiviso per errore |
| Template `truncate` | – | `escape: false` nel testo | nel testo semplice l'apostrofo diventava `&#39;` |
| `Article has_many :comments` | senza `dependent` | **`dependent: :destroy`** | eliminare un articolo lasciava commenti orfani |

## 3. I concetti chiave

### 3.1 Configurare l'invio

| Impostazione | Significato |
|---|---|
| `delivery_method` | `:smtp` (un server di posta), `:sendmail`, **`:file`** (salva in una cartella), **`:test`** (tiene le email in `ActionMailer::Base.deliveries`) |
| `smtp_settings` | `address`, `port`, `authentication` (`:plain`, `:login`, `:cram_md5`), `user_name`, `password`, `domain` |
| `default_url_options` | l'indirizzo del sito: **serve** per `article_url` nelle email (nelle email i percorsi relativi non funzionano) |
| `raise_delivery_errors` | segnalare gli errori di consegna |
| `perform_deliveries` | `false` = non consegnare mai |
| `default_options` / `default from:` | valori predefiniti (mittente) |
| `asset_host` | base per immagini negli asset |

**Segreti (le credenziali).** Mai password nei file di configurazione (finiscono in git). Rails offre le **credentials**: `config/credentials.yml.enc` è **cifrato** e si può committare; la chiave per aprirlo sta in `config/master.key` (**non** si committa, si condivide a parte). Si modifica con `bin/rails credentials:edit` (apre `$EDITOR`) e si legge con `Rails.application.credentials.smtp[:user_name]`. Qui ci sono segnaposto `CAMBIA-ME`: finché ci sono, **non si invia nulla** e le email in sviluppo finiscono in `tmp/mails/`.

**Per usare un server vero**: `bin/rails credentials:edit`, sostituire i valori, e riavviare. Con Gmail serve una **password per le app** (non quella normale). Il mittente (`default from:`) deve essere lo stesso account, o molti provider scartano il messaggio.

### 3.2 Un mailer, passo per passo

```ruby
class NotifierMailer < ApplicationMailer
  def email_friend(article, sender_name, receiver_email)
    @article = article                       # variabili d'istanza → disponibili nei template, come nei controller
    @sender_name = sender_name
    attachments[article.cover_image.filename.to_s] = article.cover_image.download if article.cover_image.attached?
    mail to: receiver_email, subject: "#{sender_name} ti consiglia un articolo: #{article.title}"
  end
end
```

Cosa ho verificato:

| Cosa | Risultato |
|---|---|
| `NotifierMailer.email_friend(...)` | restituisce un `ActionMailer::MessageDelivery`, **un involucro "pigro"**: non ha ancora costruito né inviato niente (`deliveries.size` → 0) |
| `.message` | il `Mail::Message` vero, **costruito solo qui** (con `to`, `from`, `subject`, `parts`) |
| `.deliver_now` | invia (`deliveries.size` → 1). `deliver_later` = in background (Capitolo 13) |
| Parti | `["multipart/alternative", "image/jpeg"]`: testo **e** HTML insieme, più l'allegato (41.440 byte) |
| Template | uno per formato: `email_friend.html.erb` e `email_friend.text.erb` |

**Perché testo + HTML.** I client scelgono la versione che sanno mostrare; chi legge in testo non vede un messaggio vuoto. Gli stili HTML vanno **dentro i tag** (`style="…"`): molti client ignorano i fogli di stile.

**Escape: attenzione alla differenza.** In un template **HTML** il nome `<b>Furbo</b>` viene neutralizzato (`&lt;b&gt;`); nel template **testo** no (`Tom & Jerry` resta com'è). Ma `truncate` fa l'escape comunque: nel testo serve `escape: false`, altrimenti `L'ultimo` diventa `L&#39;ultimo` (difetto trovato da un test).

### 3.3 Le anteprime (previews)

`NotifierMailerPreview < ActionMailer::Preview`: per ogni metodo, una pagina in <http://localhost:3000/rails/mailers> che mostra l'email (HTML e testo, con intestazioni) **senza inviarla**. Nella preview del commento si usa **`build`, non `create`**: altrimenti ogni anteprima aggiungerebbe un commento al database (verificato: 0 commenti creati). Gli stili delle email possono apparire diversi nei veri client di posta: si prova con più client.

### 3.4 Il callback del commento

```ruby
after_create :email_article_author
def email_article_author = NotifierMailer.comment_added(self).deliver_now if article.user
```

Verificato: un commento valido → 1 email all'**autore** dell'articolo ("Nuovo commento a «…»"); uno non valido o su una bozza → **nessuna** email (il callback parte solo dopo il salvataggio). ⚠️ Con `deliver_now` l'invio avviene **dentro la richiesta web**: se il server di posta è lento, chi commenta aspetta. Il Capitolo 13 lo risolve.

### 3.5 "Invia a un amico": un form pubblico è un rischio

Chiunque può usarlo, anche per spam: l'email contiene però solo il link e il nome scritto dal mittente. Cosa ho messo (tutto testato):

| Difesa | Perché |
|---|---|
| email valida (`URI::MailTo::EMAIL_REGEXP`) e ≤ 254 caratteri | niente destinatari falsi |
| nome obbligatorio, ≤ 60, **senza a-capo** | un nome come `Marco\r\nBcc: spia@…` aggiungerebbe un'intestazione (*header injection*); verificato: nessun `Bcc` |
| un solo destinatario per richiesta | niente invii di massa |
| solo articoli **pubblicati** | una bozza non si consiglia (e per gli altri nemmeno esiste: 404) |
| token CSRF | come ogni form |

**Mancano** un limite di invii per indirizzo IP (la gemma `rack-attack`) e un captcha: **da aggiungere prima di un uso pubblico reale**.

### 3.6 Action Mailbox: ricevere email

**Installazione**: `bin/rails action_mailbox:install` → `app/mailboxes/application_mailbox.rb` e la tabella `action_mailbox_inbound_emails` (`status`, `message_id`, `message_checksum`). Il testo grezzo dell'email è salvato con **Active Storage**.

**Stati di una email in arrivo** (`ActionMailbox::InboundEmail.statuses`): `pending`, `processing`, **`delivered`** (elaborata), **`failed`** (errore), **`bounced`** (rimbalzata di proposito con `bounce_with`).

**Il flusso del blog**

| Passo | Cosa |
|---|---|
| 1 | Ogni utente ha un `draft_article_token` casuale e unico: `iA89Wp…@drafts.example.com` |
| 2 | Il servizio di posta consegna l'email all'app (in sviluppo: il **conductor**, vedi sotto) |
| 3 | `ApplicationMailbox` la instrada: `routing /@drafts\.example\.com\z/i => :draft_articles` |
| 4 | `DraftArticlesMailbox#process`: trova l'autore dal token, crea la **bozza** (oggetto → titolo, testo → testo), risponde con un'email di conferma col link per modificarla |

```ruby
class DraftArticlesMailbox < ApplicationMailbox
  before_processing :require_author          # come un before_action
  def process
    articolo = author.articles.new(title: mail.subject, body: PlainText.to_html(testo_del_messaggio))
    articolo.save ? DraftArticlesMailer.created(mail.from, articolo).deliver_now
                  : bounce_with(DraftArticlesMailer.invalid_draft(mail.from, articolo.errors.full_messages))
  end
  def author = @author ||= User.find_by(draft_article_token: token)       # memoization: una sola query
end
```

Verificato (nei test e nello script): indirizzo giusto → `delivered`, bozza **non pubblicata**, conferma con il link `/articles/ID/edit`; indirizzo sbagliato → `bounced`, nessuna bozza, risposta al mittente; senza oggetto → `bounced` con "Titolo è obbligatorio"; email **multipart** → si usa la parte di testo; **solo HTML** → si tolgono i tag; HTML nel testo → **neutralizzato** (`&lt;script&gt;`); dominio **altro** → `RoutingError` (nessuna mailbox corrisponde); dopo aver **rigenerato** il token il vecchio indirizzo rimbalza.

**Routing**: le regole si leggono **dall'alto in basso e vince la prima** (come le route); si può usare una regex, una stringa, `:all`, o una proc. Una regex si confronta con **ogni destinatario**.

**Provarlo in sviluppo (il "conductor")**: <http://localhost:3000/rails/conductor/action_mailbox/inbound_emails/new> è un modulo che "consegna" un'email all'app, senza servizi esterni. Ho provato: l'email è risultata `delivered`, la bozza è comparsa **solo** per Mary (404 per i visitatori) e la conferma è finita in `tmp/mails/`.

**Opzioni di configurazione** (`config.action_mailbox.…`): `ingress` (`:relay`, `:mailgun`, `:mandrill`, `:postmark`, `:sendgrid`: i servizi che consegnano le email vere), `incinerate` (conserva o no le email elaborate), `incinerate_after` (default 30 giorni), `logger`, `queues`. Ricevere email **vere** richiede un dominio e un servizio di posta in arrivo: il libro non lo copre.

⚠️ **Sicurezza**: l'indirizzo con il token è un **segreto**. Chi lo conosce può creare bozze a nome dell'utente; il mittente (`From`) non viene verificato (si può falsificare). Per questo: bozze **mai pubbliche** e possibilità di rigenerare il token.

## 4. Trappole e scoperte

| Cosa | Spiegazione |
|---|---|
| Il test del testo dell'email trovò `&#39;` | `truncate` fa l'escape anche nei template di testo: `escape: false` |
| `to_sentence` dice "and" | usa la lingua predefinita (inglese): `to_sentence(two_words_connector: " e ", last_word_connector: " e ")` |
| `receive_inbound_email_from_mail` (Rails 6.0) | non passa il blocco a `Mail.new`: per email multipart si costruisce il messaggio a mano e si usa `receive_inbound_email_from_source` |
| `inline` e il job di incenerimento | l'adattatore `inline` non sa programmare job futuri: negli script `ActionMailbox.incinerate = false` |
| Doppia elaborazione | creare una `InboundEmail` la instrada **già da sola** (callback); chiamare anche `.route` crea due bozze. Nei test, dove i job non girano, `.route` serve |
| `failed` in sviluppo | un'email consegnata mentre altri processi scrivevano su SQLite → `database is locked` (un solo scrittore alla volta). Ho alzato `timeout` in `database.yml` a 15 s; dal conductor si può **ri-instradare** |
| `autore.articles.order(:id).last` | l'associazione ha un ordinamento predefinito: `order(:id)` si **aggiunge**, non lo sostituisce. Per l'ultimo per id: `Article.where(user: autore).order(:id).last` |
| Commenti orfani | `has_many :comments` senza `dependent`: eliminare un articolo li lasciava; trovati 4 commenti di prova orfani e ripuliti |
| Una bozza e i commenti | prima: 422 con messaggio; ora: **404** per i visitatori (non la vedono); per l'autore resta 422 |
| Nomi delle email in `tmp/mails/` | un file per destinatario (`amico@example.com`), con le intestazioni leggibili (l'oggetto è codificato) |
| Il piano originale del capitolo | "Notify a Friend" col `deliver` del libro (`.deliver` è un vecchio alias): qui `deliver_now` |

## 5. Come provarlo

```bash
bin/rails server
# 1) anteprime:        http://localhost:3000/rails/mailers
# 2) invia a un amico: apri un articolo pubblicato → "Invia questo articolo a un amico" → le email stanno in tmp/mails/
# 3) bozza per email:  accedi, "Scrivi": copia il TUO indirizzo; poi
#                      http://localhost:3000/rails/conductor/action_mailbox/inbound_emails/new
#                      (To = il tuo indirizzo, oggetto = titolo, messaggio = testo) → la bozza compare nel tuo elenco
bin/rails test        # 206 test
PATH="$HOME/.local/bin:$PATH" bin/rails runner capitoli/capitolo12_esercizi.rb
```

## 6. Checklist del capitolo

- [x] Configurare Action Mailer (SMTP, credenziali cifrate, opzioni, `default_url_options`)
- [x] Generare un mailer e i template (testo + HTML), layout delle email
- [x] "Invia a un amico": route `member`, form, azione, `deliver_now`
- [x] Anteprime (`ActionMailer::Preview`, con `build`)
- [x] Allegati (`attachments` + Active Storage)
- [x] Avviso all'autore per i commenti (callback del Capitolo 6)
- [x] Action Mailbox: installazione, `has_secure_token`, mailbox, `bounce_with`, routing
- [x] Rispondere all'autore (`DraftArticlesMailer`: `no_author`, `created`)
- [x] Prova con il conductor
- [x] 206 test; script con le prove

## 7. Auto-verifica

1. Perché `NotifierMailer.email_friend(...)` non invia nulla finché non si chiama `deliver_now`?
2. Perché le email vogliono sia la versione in testo sia quella HTML?
3. Che rischio c'è nel mettere il nome scelto dall'utente nell'oggetto di un'email?
4. Perché l'anteprima del commento usa `build` e non `create`?
5. A cosa serve `has_secure_token` e perché l'indirizzo per le bozze è "segreto"?
6. Che differenza c'è tra `delivered`, `bounced` e `failed` per un'email in arrivo?
7. Perché non bisogna salvare le password SMTP in `config/environments/development.rb`?

<details><summary>Risposte</summary>

1. Il mailer restituisce un `MessageDelivery` "pigro": il messaggio si costruisce quando serve e si invia solo con `deliver_now` (o `deliver_later`).
2. Il client di posta mostra la versione che sa leggere; chi non vede l'HTML non resta con un messaggio vuoto. Gli stili HTML devono essere "in linea" nei tag.
3. L'*header injection*: un nome con a-capo e altre intestazioni (`Bcc: …`) potrebbe aggiungere destinatari. Per questo si tolgono i caratteri di controllo, e Mail neutralizza il resto.
4. `create` aggiungerebbe un commento al database a ogni visualizzazione; `build` crea l'oggetto senza salvarlo.
5. Genera un valore casuale e unico alla creazione di un utente. L'indirizzo `<token>@dominio` è l'unica prova che chi scrive è l'autore (il `From` si può falsificare): chi lo conosce può creare bozze.
6. `delivered`: elaborata con successo; `bounced`: respinta di proposito (`bounce_with`, con risposta al mittente); `failed`: errore non gestito durante l'elaborazione.
7. Il file finisce in git (e su ogni computer e server): i segreti vanno nelle credentials cifrate (`credentials.yml.enc`), con la chiave in `master.key` fuori da git.

</details>

---

**Prossimo capitolo**: il **13** tratta **Active Job**: eseguire in background le operazioni lente. È la soluzione al problema che qui abbiamo lasciato aperto: l'invio dell'email di un commento (`deliver_now`) rallenta chi commenta; con `deliver_later` partirà in un job.
