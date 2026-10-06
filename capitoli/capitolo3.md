# Capitolo 3 — Far girare qualcosa (il blog)

> **In una frase**: crei da zero un'app Rails con una tabella `articles` e un CRUD completo (elenco, dettaglio, crea, modifica, elimina) in pochi comandi, e capisci come i pezzi si collegano.

Spiegazione estesa passo per passo: cartella [guida/](../guida/README.md). Qui trovi la versione corta, con il contesto.

## 1. Il contesto (la mappa mentale)

Rails divide l'app in tre ruoli (**MVC**). Tutto il capitolo serve a costruirli per gli articoli:

```
Browser: GET /articles/1
  → ROUTE        config/routes.rb         "resources :articles" → articles#show
  → CONTROLLER   articles_controller.rb   cerca l'articolo (set_article)
  → MODELLO      article.rb               parla con la tabella "articles" nel DB
  → VISTA        views/articles/show.html.erb   costruisce l'HTML
  → Browser
```

Principio guida: **convenzioni invece di configurazione**. Se i nomi sono quelli giusti, Rails collega tutto da solo.

| Cosa | Nome | Esempio |
|---|---|---|
| Modello | singolare, CamelCase | `Article` |
| Tabella | plurale, snake_case | `articles` |
| Controller | plurale | `ArticlesController` |
| Viste | cartella plurale | `app/views/articles/` |

## 2. Cosa ho fatto, in ordine

| # | Cosa | Comando | Risultato |
|---|---|---|---|
| 1 | Creare l'app | `rails new blog` | struttura di cartelle (già fatto, + fix per Node 18) |
| 2 | Leggere `config/database.yml` | — | 3 ambienti: `development`, `test`, `production`, ognuno col suo DB SQLite |
| 3 | Creare i database | `bin/rails db:create` e `db:create:all` | 3 file `.sqlite3` in `db/` |
| 4 | Entrare nel DB | `bin/rails dbconsole` | prompt SQLite (`.databases`, `.exit`) |
| 5 | Generare il modello | `bin/rails g model Article` | modello vuoto + migrazione + test |
| 6 | Scrivere la migrazione | in `db/migrate/` | `title:string`, `body:text`, `published_at:datetime`, `timestamps` |
| 7 | Eseguirla | `bin/rails db:migrate` | tabella `articles` creata |
| 8 | Annullarla | `bin/rails db:rollback` | tabella eliminata **senza scrivere codice per farlo** |
| 9 | Rieseguirla | `bin/rails db:migrate` | tabella di nuovo presente |
| 10 | Generare il controller | `bin/rails g controller articles` | controller vuoto + cartella viste + helper |
| 11 | Annullare tutto | `destroy controller` → `db:rollback` → `destroy model` | progetto pulito |
| 12 | Scaffold | `bin/rails g scaffold Article title:string body:text published_at:datetime` + `db:migrate` | CRUD completo funzionante |
| 13 | Provarlo | `bin/rails server` → `/articles` | creato un articolo, redirect a `show` |
| 14 | Nuove colonne | `bin/rails g migration add_excerpt_and_location_to_articles excerpt:string location:string` + `db:migrate` | `excerpt` e `location` aggiunte, dati intatti |
| 15 | Aggiornare le pagine | `rm` di 3 file + `g scaffold ... --no-migration --force` | form con i nuovi campi |
| 16 | Validazioni | `validates :title, :body, presence: true` | articolo vuoto rifiutato (422) |
| 17 | Leggere il controller | Listato 3-6 | le 7 azioni CRUD capite |

Ordine importante al punto 11: **prima `db:rollback`, poi `destroy model`**, perché il rollback ha bisogno del file di migrazione.

## 3. I concetti chiave

**Migrazione.** Un file Ruby che descrive una modifica al DB: crea tabelle, aggiunge colonne. `def change` basta: Rails sa invertirla. Il nome del file inizia con un timestamp, quindi ha un ordine univoco. `db:migrate` esegue quelle in sospeso, `db:rollback` annulla l'ultima, `db/schema.rb` è la fotografia aggiornata del DB (non si modifica a mano). **Mai modificare una migrazione già eseguita da altri: se ne scrive una nuova.**

**Generatore.** `bin/rails g ...` crea file seguendo le convenzioni e non sbaglia i nomi. `destroy` è il suo contrario.

**Scaffold.** Un generatore che crea in un colpo modello, migrazione, controller, viste e route. Ottimo per prototipi e per studiare; **non** è codice da produzione, e rigenerarlo sovrascrive le tue modifiche.

**Le 7 azioni REST** (`resources :articles` crea le route):

| Azione | Verbo + URL | Fa |
|---|---|---|
| `index` | GET `/articles` | elenco |
| `show` | GET `/articles/1` | dettaglio |
| `new` / `create` | GET `/articles/new` / POST `/articles` | form vuoto / salva |
| `edit` / `update` | GET `/articles/1/edit` / PATCH `/articles/1` | form compilato / salva |
| `destroy` | DELETE `/articles/1` | elimina |

**Validazione.** Una regola nel **modello** (non nel form) che impedisce di salvare dati non validi. Vale ovunque: form, API, console. `save` restituisce `false` se non è valido e non scrive nel DB.

**Strong parameters.** `params.require(:article).permit(:title, ...)` accetta **solo** i campi elencati: protegge da chi invia campi extra. Se aggiungi un campo e non si salva, controlla qui per prima cosa.

**Altri punti del controller:**
- `before_action :set_article` cerca l'articolo una volta sola per `show/edit/update/destroy` (DRY).
- `@variabili` del controller sono visibili nella vista.
- Dopo un salvataggio riuscito: `redirect_to` (nuova richiesta). Dopo un errore: `render` (stessa richiesta, il form conserva i dati).
- Il messaggio `notice:` (flash) sopravvive al redirect e si mostra una volta.

**Ambienti.** `development` è quello predefinito. Non serve riavviare il server per le modifiche in `app/`; serve per quelle in `config/`.

## 4. Cose che ho incontrato (e che al lavoro ti capiteranno)

| Cosa | Spiegazione |
|---|---|
| Rails 6.0 su Node 18 non va out of the box | webpack 4 e `node-sass` sono vecchi: soluzione in [FIX_NODE_COMPATIBILITY.md](../FIX_NODE_COMPATIBILITY.md) |
| Il tuo controller ≠ Listato 3-6 | il generatore 6.0.6 è più recente: `status: :unprocessable_entity` (422) sui render di errore, `status: :see_other` su `destroy`. Stessa logica |
| `422` su un DELETE da `curl` | `Can't verify CSRF token authenticity`: ogni richiesta che scrive richiede un token legato alla sessione. Il browser lo gestisce da solo |
| `"already exists"` su `db:create` | non è un errore: il DB c'era già |

## 5. Stato del progetto dopo il capitolo

- Tabella `articles`: `title`, `body`, `published_at`, `excerpt`, `location`, `created_at`, `updated_at`.
- `Article` con `validates :title, :body, presence: true`.
- CRUD completo su `/articles` (e `/articles.json`).
- 7 test del controller generati dallo scaffold, tutti verdi.

(In seguito il blog è stato ridisegnato: vedi [guida/09](../guida/09-grafica-landing-navbar.md).)

## 6. Checklist del capitolo

- [x] Struttura di un'app Rails e `database.yml`
- [x] Database creati (`db:create`, `db:create:all`) e verificati con `dbconsole`
- [x] Modello `Article`, migrazione, `db:migrate`, `db:rollback`
- [x] Controller generato e poi annullato con `destroy`
- [x] Scaffold completo provato nel browser
- [x] Nuove colonne con una migrazione e scaffold rigenerato
- [x] Validazioni testate (prima e dopo)
- [x] Controller generato letto e capito

## 7. Auto-verifica

1. Come si chiamano tabella e controller per un modello `Comment`?
2. Perché `db:rollback` va fatto prima di `destroy model`?
3. Cosa succede ai dati esistenti quando aggiungi una colonna con una migrazione?
4. Hai aggiunto `:subtitle` al form ma non si salva: dove guardi?
5. Dopo un errore di validazione: `redirect_to` o `render`? Perché?

<details><summary>Risposte</summary>

1. Tabella `comments`, controller `CommentsController`.
2. Il rollback usa il file di migrazione per sapere cosa annullare; se lo cancelli prima, la tabella resta.
3. Restano; la nuova colonna vale `nil` (o il default).
4. In `article_params` (il `permit`) e nel log (`Unpermitted parameter`).
5. `render`: mantiene lo stesso oggetto con dati ed errori, così il form si ripopola.

</details>
