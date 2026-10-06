# Capitolo 6 — Active Record avanzato: potenziare i modelli

> **In una frase**: un modello non è solo una tabella. Gli dai metodi, lo colleghi agli altri modelli (**associazioni**), cerchi i dati in modo avanzato (**where e scope**), e gli fai rispettare regole (**validazioni**) e reagire agli eventi (**callback**).

## 1. Il contesto (la mappa mentale)

Fino al Capitolo 5 il blog aveva **una tabella**. Qui diventa un'applicazione vera, con questi modelli:

```
User ──1:1── Profile
  │
  └─1:N── Article ──N:M── Category        (tabella ponte: articles_categories)
              │
              └─1:N── Comment

User ──N:M ricca── Comment                (User "ha molti commenti ATTRAVERSO i suoi articoli" = replies)
```

Regola che regge tutto: **la chiave esterna sta nella tabella "figlia"**, e quel modello dichiara `belongs_to`.

| Relazione | Modello "padre" | Modello "figlio" (ha la chiave esterna) |
|---|---|---|
| Utente ha un profilo | `User` → `has_one :profile` | `Profile` → `belongs_to :user` (colonna `user_id`) |
| Utente ha molti articoli | `User` → `has_many :articles` | `Article` → `belongs_to :user` (`user_id`) |
| Articolo ha molti commenti | `Article` → `has_many :comments` | `Comment` → `belongs_to :article` (`article_id`) |
| Articoli ↔ categorie | `has_and_belongs_to_many` da entrambi i lati | nessuno: serve una **tabella ponte** |

Convenzione del nome della chiave: `nome_singolare_del_padre_id` (`user_id`, `article_id`, `person_id`).

## 2. Cosa ho fatto

**Migrazioni (nell'ordine del libro):**

| # | Comando | Effetto |
|---|---|---|
| 1 | `bin/rails g model User email:string password:string` | tabella `users` |
| 2 | `bin/rails g model Profile user:references name:string birthday:date bio:text color:string twitter:string` | tabella `profiles` con chiave esterna `user_id` |
| 3 | `bin/rails g migration add_user_reference_to_articles user:references` (tolto `null: false`) | colonna `articles.user_id` |
| 4 | `bin/rails g model Category name:string` | tabella `categories` |
| 5 | `bin/rails g migration CreateJoinTableArticlesCategories article category` (attivati i due indici) | tabella ponte `articles_categories`, **senza** `id` |
| 6 | `bin/rails g model comment article_id:integer name:string email:string body:text` | tabella `comments` |
| 7 | `bin/rails g migration rename_password_to_hashed_password` | `rename_column :users, :password, :hashed_password` |

Al punto 3 il libro dice di togliere `null: false`: gli articoli che esistono già non hanno un `user_id`, e la migrazione fallirebbe.

**Modelli** (tutti in `app/models/`), **dati seme** (`db/seeds.rb`), **fixture e test** (40 test, tutti verdi) e **tutti gli esempi di console** in [capitolo6_esercizi.rb](capitolo6_esercizi.rb):

```bash
bin/rails db:migrate                               # già fatto
bin/rails db:seed                                  # utente, 5 categorie, 4 articoli collegati
bin/rails runner capitoli/capitolo6_esercizi.rb    # gli esempi (annullati a fine corsa)
bin/rails test                                     # 40 test
```

### Dove ho deviato dal libro (e perché)

| Cosa | Libro | Qui | Motivo |
|---|---|---|---|
| `Article belongs_to :user` | obbligatorio | **`optional: true`** | senza login (Capitolo 8) il form non sa chi è l'autore: ogni salvataggio fallirebbe con "Utente deve esistere". Tornerà obbligatorio col login |
| Scope `recent` | articoli dell'ultima settimana | uguale. Il mio ordinamento del passo 9 è diventato **`latest_first`** | il nome `recent` era già occupato |
| Categorie | Programming, Event, Travel, Music, TV | **NBA, Serie A, Tattica, Allenamento, Storia** | sono i 5 temi della landing page |
| `has_one :profile` | senza `dependent` | **`dependent: :destroy`** | senza, eliminare un utente con profilo fallisce per la chiave esterna (l'ho scoperto eseguendo gli esempi) |
| Messaggi d'errore | inglese | italiano, in `config/locales/` | coerenza col resto del sito. Nei modelli resta `presence: true` |
| Seed | `db:seed` duplica se rilanciato | `find_or_create_by!` | rilanciabile senza duplicati e senza sovrascrivere |
| Comment `after_create` | `article.user.email` | con `if article.user` | gli articoli possono non avere autore |
| Esercizi | in console, sul DB | in una transazione annullata | i dati del blog non si toccano |

## 3. I concetti chiave

### 3.1 Aggiungere metodi al modello

Un modello è una normale classe Ruby: ci metti i tuoi metodi. Sono "attributi calcolati" disponibili ovunque.

```ruby
def long_title    "#{title} - #{published_at}"   end   # Article#long_title
def published?    published_at.present?          end
```

**Modelli "grassi"**: la logica che riguarda i dati sta nel modello (non nel controller o nella vista), così si riusa e non si ripete (DRY). Ma un metodo usato in un solo punto, e mai più, non serve.

### 3.2 Associazioni: i metodi che ottieni gratis

| Dichiari | Ottieni (esempi) |
|---|---|
| `has_one :profile` | `user.profile`, `user.build_profile(attrs)` (non salva), `user.create_profile(attrs)` (salva) |
| `has_many :articles` | `user.articles`, `user.articles << art`, `user.articles.create(attrs)`, `.build`, `.size`, `.empty?`, `.clear`, `user.article_ids` |
| `belongs_to :user` | `article.user`, `article.user = u` |
| `has_and_belongs_to_many :categories` | `article.categories << cat`, e `cat.articles` (funziona nei due versi) |

**Opzioni più usate** (`has_one` / `has_many`):

| Opzione | Significato |
|---|---|
| `class_name:` / `foreign_key:` | quando i nomi non seguono la convenzione |
| `dependent: :destroy` | elimina anche gli oggetti collegati (esegue i callback) |
| `dependent: :delete` | li elimina direttamente via SQL (senza callback) |
| `dependent: :nullify` | non li elimina: mette la chiave esterna a `NULL` (restano "orfani") |
| `-> { order 'published_at DESC' }` | ordine predefinito della collezione (uno scope in una *lambda*) |

Cosa ho verificato nell'esecuzione:
- `user.articles.clear` **non cancella** gli articoli: azzera il loro `user_id` (con `dependent: :nullify`).
- Eliminare un utente con `dependent: :nullify`: gli articoli restano, con `user_id = nil`.
- `User.delete(id)` salta i callback e, se ci sono righe collegate, il database **rifiuta** (`FOREIGN KEY constraint failed`). `user.destroy` invece esegue prima il `:nullify`/`:destroy` e riesce.
- `has_one`: se c'è già un profilo, `build_profile` / `create_profile` **sostituiscono** quello vecchio (con `dependent: :destroy` lo eliminano subito).

### 3.3 `belongs_to` è anche una validazione

Dal Rails 5 un `belongs_to` è **obbligatorio per impostazione predefinita**: creare un `Profile` senza utente fallisce con `["Utente deve esistere"]` (in inglese: *"User must exist"*). Per renderlo facoltativo: `belongs_to :user, optional: true`.

### 3.4 Molti-a-molti: due strade

| | `has_and_belongs_to_many` (habtm) | `has_many :through` |
|---|---|---|
| Tabella ponte | sì, **senza** modello e **senza** `id` | sì, con un **modello vero** |
| Dati sul legame | no | sì (data, motivo...) |
| Nome tabella | i due nomi al plurale, **in ordine alfabetico**: `articles_categories` | a piacere |
| Nel blog | Article ↔ Category | `User` → articoli → commenti |

```ruby
class User < ApplicationRecord
  has_many :articles
  has_many :replies, through: :articles, source: :comments   # i commenti ricevuti sui miei articoli
end
```

`source:` dice "prendi l'associazione `comments` di Article, ma chiamala `replies`". Rails costruisce un `INNER JOIN` da solo (vedi `autore.replies.to_sql` nello script).

La tabella ponte si crea con `create_join_table` (che sa di non volere la chiave primaria); i due `t.index` la rendono veloce nelle ricerche.

### 3.5 Ricerca avanzata: `where` in 4 forme

| Forma | Esempio | Quando |
|---|---|---|
| Hash | `Article.where(title: 'X')` | uguaglianze, condizioni in AND |
| Frammento SQL | `where("title = 'X' OR ...")` | flessibile, ma **mai con dati dell'utente** |
| **Array con `?`** | `where('published_at < ?', Time.now)` | **la scelta sicura** per i valori variabili |
| Segnaposto nominati | `where('title LIKE :q OR body LIKE :q', {q: '%x%'})` | stesso valore più volte |

`to_sql` mostra la query reale senza eseguirla.

**⚠️ SQL injection (verificata nello script).** Con `cattivo = "x' OR '1'='1"`:

| Codice | SQL risultante | Articoli trovati |
|---|---|---|
| `where("title = '#{cattivo}'")` ❌ | `WHERE (title = 'x' OR '1'='1')` | **tutti** (condizione sempre vera) |
| `where('title = ?', cattivo)` ✅ | `WHERE (title = 'x'' OR ''1''=''1')` | nessuno |

Con il `?` Rails mette il valore tra apici e fa l'escape: l'input resta un dato, non diventa codice. **Mai interpolare (`#{}`) input dell'utente dentro SQL.**

**Association proxy = ricerche limitate al proprietario.** `autore.articles.find(id)` trova solo gli articoli **di quell'autore**: con l'id di un altro solleva `RecordNotFound` (verificato). `Article.find(id)` invece trova tutto. In un sistema multiutente si usa il primo (`current_user.articles.find(...)`), anche per creare: `current_user.articles.create(...)` imposta da solo `user_id`.

**Altri finder, concatenabili:** `order`, `limit`, `joins(:comments)` (unisce le tabelle, serve per filtrare), `includes(:comments)` (carica in anticipo le associazioni: evita di fare una query per ogni articolo, il cosiddetto "problema N+1").

### 3.6 Scope

| | Cosa fa | Esempio |
|---|---|---|
| `default_scope { order :name }` | si applica **sempre** | `Category.all` → sempre in ordine alfabetico (`unscoped` per saltarlo) |
| `scope :published, -> { ... }` | query con un nome | `Article.published`, `.draft`, `.recent`, `.where_title("x")` |

```ruby
scope :published,   -> { where.not(published_at: nil) }
scope :draft,       -> { where(published_at: nil) }
scope :recent,      -> { where('articles.published_at > ?', 1.week.ago.to_date) }
scope :where_title, -> (term) { where("articles.title LIKE ?", "%#{term}%") }
```

- Si **concatenano**: `Article.published.recent.where_title('commenti')`.
- Serve la **lambda** (`-> { }`) perché va rivalutata a ogni uso: senza, `1.week.ago` verrebbe calcolato una volta sola e darebbe risultati "vecchi".
- Usa il `default_scope` solo per l'ordinamento: una condizione lì dentro si applica **sempre**, anche dove non te l'aspetti.

### 3.7 Validazioni

| Validazione | Esempio | Nota |
|---|---|---|
| `presence` | `validates :title, presence: true` | non vuoto |
| `uniqueness` | `validates :email, uniqueness: true` | anche con `scope:`. Serve **anche** un indice `unique` nel DB (due richieste simultanee) |
| `length` | `length: { in: 5..50 }` | anche `minimum`, `maximum`, `is` |
| `format` | `format: { with: /regex/i }` | email, codici... |
| `confirmation` | `validates :password, confirmation: true` | crea l'attributo **virtuale** `password_confirmation` |
| `acceptance` | `acceptance: true` | "accetto i termini" |

Opzioni comuni: `message:`, `on: :create / :update`, `if:` / `unless:` (condizionali).

**Validazione personalizzata:** un metodo che aggiunge errori, registrato con `validate`:

```ruby
validate :article_should_be_published

def article_should_be_published
  errors.add(:article_id, "non è ancora pubblicato") if article && !article.published?
end
```

(Prima si controlla `article &&` per non sollevare un errore su `nil`; se manca, ci pensa un'altra validazione.) Effetto: nessun commento sugli articoli in bozza (testato).

### 3.8 Callback

Metodi che il modello esegue da solo in un momento preciso: `before_/after_` + `create`, `save`, `destroy`.

```ruby
after_create :email_article_author    # dopo la creazione di un commento
```

Si passa il **simbolo** del metodo (più leggibile, e puoi metterne più di uno).

⚠️ **Il libro è datato su un punto**: dice che un callback `before_` che restituisce `false` interrompe il salvataggio. **Non è più vero dal Rails 5**: per fermare la catena si scrive `throw :abort`. Per tenerlo a mente: se un modello non si salva senza un motivo, controlla i `before_*`.

### 3.9 Il modello User e la password

```
password in chiaro ──(before_save)──► SHA1 ──► hashed_password nel DB
        ▲                                         
 attr_accessor :password                    (la password in chiaro non è MAI salvata)
```

| Pezzo | A cosa serve |
|---|---|
| `attr_accessor :password` | attributo solo in memoria (la colonna ora si chiama `hashed_password`) |
| `before_save :encrypt_new_password` | prima di salvare, se c'è una password, ne salva l'hash |
| `password_required?` | valida la password solo se l'utente è nuovo **o** se ne sta impostando una nuova (così modifichi l'email senza risetarla) |
| `User.authenticate(email, pwd)` | metodo di **classe** (`self.`): restituisce l'utente o `nil` |
| `authenticated?(pwd)` | confronta l'hash della password data con quello salvato |
| `protected` | `encrypt_new_password`, `password_required?`, `encrypt` non sono chiamabili da fuori |

Verificato: `User.authenticate('login@example.com', 'secret')` → l'utente; con la password sbagliata o l'email inesistente → `nil`. Cambiando l'email senza password, l'hash non cambia.

**⚠️ SHA1 senza "sale" è debole.** È quello che usa il libro, solo a scopo didattico (lo dice anche lui). In un sito vero si usa **`has_secure_password`** (incluso in Rails) con la gem **bcrypt**. Nel seed c'è un utente `mary@example.com` con password `guessit`: **non tenerlo mai su un sito pubblico**.

## 4. Trappole e problemi incontrati

| Trappola | Cosa succede | Rimedio |
|---|---|---|
| `Profile.create` senza utente | non salva: "Utente deve esistere" | assegna prima `profile.user = user` o usa `user.create_profile(...)` |
| `belongs_to` obbligatorio con dati già presenti | gli articoli esistenti non hanno `user_id` | `optional: true`, o migrazione senza `null: false` |
| `add_reference ... null: false` su tabella con righe | la migrazione fallisce | toglierlo (come dice il libro) |
| `user.articles.clear` | gli articoli **non** sono eliminati, solo scollegati | `destroy_all` per eliminarli davvero |
| `User.delete(id)` / eliminare con figli | `FOREIGN KEY constraint failed` | `destroy` + `dependent:` |
| `has_one` senza `dependent` | l'utente con profilo non si elimina | `dependent: :destroy` (aggiunta mia) |
| SQL con `#{}` | SQL injection | array con `?` o hash |
| `errors` letti prima di `valid?` | vuoti | prima `save` o `valid?` |
| `rake db:seed` due volte | duplicati (nel libro) | `find_or_create_by!` |
| `reload!` in console | le variabili vanno perse | ricrea gli oggetti; o riapri la console |

## 5. Checklist del capitolo

- [x] Metodi di istanza nel modello (`long_title`, `published?`)
- [x] Chiavi esterne e convenzioni dei nomi
- [x] Uno-a-uno: `User`/`Profile` (`has_one`, `build_`, `create_`)
- [x] Uno-a-molti: `User`/`Article`, opzioni `order` e `dependent`
- [x] Molti-a-molti: `habtm` con tabella ponte (`Article`/`Category`)
- [x] Molti-a-molti ricco: `has_many :through` (`replies`)
- [x] Ricerca: hash, frammento SQL, array, segnaposto, `to_sql`, association proxy, finder concatenabili
- [x] `default_scope` e named scope (`published`, `draft`, `recent`, `where_title`)
- [x] Validazioni integrate (presenza, unicità, lunghezza, formato, conferma) e personalizzata
- [x] Callback (`after_create`)
- [x] `User`: password cifrata, `authenticate`; migrazione `rename_column`
- [x] Seed con utente, categorie e articoli
- [x] Modelli finali allineati ai Listati 6-36/6-37/6-38
- [x] Blog ancora funzionante (pagine 200, creazione di un articolo senza utente ok)

## 6. Auto-verifica

1. In quale tabella sta la chiave esterna di "un articolo ha molti commenti", e quale modello dichiara `belongs_to`?
2. Perché la tabella ponte tra `articles` e `categories` si chiama `articles_categories` e non ha `id`?
3. Differenza tra `dependent: :destroy` e `:nullify`?
4. Perché `Article.where("title = '#{params[:q]}'")` è pericoloso, e come si scrive in modo sicuro?
5. Perché uno scope vuole una lambda?
6. Perché modificare l'email di un utente esistente non richiede di reinserire la password?

<details><summary>Risposte</summary>

1. In `comments` (`article_id`); `Comment` dichiara `belongs_to :article`.
2. Il nome è formato dai due nomi in ordine alfabetico; è una tabella di solo collegamento, non un'entità, quindi non serve una chiave primaria.
3. `:destroy` elimina anche gli oggetti collegati (con callback); `:nullify` li lascia e mette la chiave esterna a `NULL`.
4. L'input dell'utente diventa parte dell'SQL (SQL injection). Sicuro: `where('title = ?', params[:q])` (o `where(title: params[:q])`).
5. Così viene rivalutata a ogni uso; senza, valori come `1.week.ago` resterebbero quelli del primo utilizzo.
6. `password_required?` è vero solo se `hashed_password` è vuoto (utente nuovo) o se `password` è valorizzata; altrimenti le validazioni sulla password sono saltate e l'hash resta.

</details>

---

**Prossimo capitolo**: il 7 (le **viste**): ERB, helper, partial e layout. Userà i modelli di questo capitolo (categorie, commenti, autore) per costruire le pagine del blog.
