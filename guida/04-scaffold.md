# Passo 4 — Annullare tutto e rifarlo con lo scaffold

**Obiettivo**: cancellare in modo pulito quanto generato nei passi 2-3, poi rigenerare tutto (modello, migrazione, controller, viste, route) con un solo comando, e provarlo nel browser.

**Nel libro**: "Operativi in un attimo con lo scaffolding".

---

## 4.1 Annullare: `destroy` e `db:rollback`

Ogni `generate` ha il suo contrario, `destroy`, che cancella esattamente i file creati. L'ordine è importante:

```bash
bin/rails destroy controller articles   # 1. via il controller
bin/rails db:rollback                   # 2. via la tabella (PRIMA di cancellare la migrazione!)
bin/rails destroy model Article         # 3. via modello e migrazione
```

Output reale:

```
      remove  app/controllers/articles_controller.rb
      invoke  erb
      remove    app/views/articles
      ...
      remove      app/assets/stylesheets/articles.scss

== 20261001123550 CreateArticles: reverting ===================================
-- drop_table(:articles)
   -> 0.0053s
== 20261001123550 CreateArticles: reverted (0.0084s) ==========================

      invoke  active_record
      remove    db/migrate/20261001123550_create_articles.rb
      remove    app/models/article.rb
      invoke    test_unit
      remove      test/models/article_test.rb
      remove      test/fixtures/articles.yml
```

**Perché il rollback va fatto prima del destroy del modello?** Il rollback ha bisogno del file di migrazione per sapere cosa annullare. Se cancelli prima il file, la tabella resta nel DB e Rails non sa più come toglierla.

## 4.2 Lo scaffold

```bash
bin/rails generate scaffold Article title:string body:text published_at:datetime
bin/rails db:migrate
```

La sintassi `nome:tipo` scrive le colonne nella migrazione al posto tuo.

Output reale (commentato):

```
      invoke  active_record
      create    db/migrate/20261001123624_create_articles.rb   ← migrazione già completa
      create    app/models/article.rb                          ← modello
      create      test/models/article_test.rb
      create      test/fixtures/articles.yml
      invoke  resource_route
       route    resources :articles                            ← aggiunta a config/routes.rb
      invoke  scaffold_controller
      create    app/controllers/articles_controller.rb         ← controller con 7 azioni
      create      app/views/articles/index.html.erb            ← elenco
      create      app/views/articles/edit.html.erb             ← pagina modifica
      create      app/views/articles/show.html.erb             ← dettaglio
      create      app/views/articles/new.html.erb              ← pagina creazione
      create      app/views/articles/_form.html.erb            ← form condiviso da new ed edit
      create      test/controllers/articles_controller_test.rb
      create      test/system/articles_test.rb
      create      app/helpers/articles_helper.rb
      invoke    jbuilder
      create      app/views/articles/index.json.jbuilder       ← versione JSON (API)
      create      app/views/articles/show.json.jbuilder
      create      app/views/articles/_article.json.jbuilder
      create      app/assets/stylesheets/articles.scss
      create    app/assets/stylesheets/scaffolds.scss          ← stile base delle pagine scaffold

== 20261001123624 CreateArticles: migrating ===================================
-- create_table(:articles)
   -> 0.0058s
== 20261001123624 CreateArticles: migrated (0.0059s) ==========================
```

## 4.3 Le route: `resources :articles`

Lo scaffold ha aggiunto una riga a [config/routes.rb](../config/routes.rb):

```ruby
Rails.application.routes.draw do
  resources :articles
end
```

Questa sola riga crea **8 route**. Le vedi con:

```bash
bin/rails routes -c articles
```

```
      Prefix Verb   URI Pattern                  Controller#Action
    articles GET    /articles(.:format)          articles#index
             POST   /articles(.:format)          articles#create
 new_article GET    /articles/new(.:format)      articles#new
edit_article GET    /articles/:id/edit(.:format) articles#edit
     article GET    /articles/:id(.:format)      articles#show
             PATCH  /articles/:id(.:format)      articles#update
             PUT    /articles/:id(.:format)      articles#update
             DELETE /articles/:id(.:format)      articles#destroy
```

Come si legge:

| Azione | Verbo + URL | Operazione CRUD | Cosa fa |
|---|---|---|---|
| `index` | GET `/articles` | Read | elenco di tutti gli articoli |
| `show` | GET `/articles/1` | Read | un articolo |
| `new` | GET `/articles/new` | — | mostra il form vuoto |
| `create` | POST `/articles` | Create | salva il form di `new` |
| `edit` | GET `/articles/1/edit` | — | mostra il form compilato |
| `update` | PATCH/PUT `/articles/1` | Update | salva il form di `edit` |
| `destroy` | DELETE `/articles/1` | Delete | cancella |

- Lo **stesso URL** fa cose diverse a seconda del **verbo HTTP**: `/articles/1` con GET mostra, con PATCH aggiorna, con DELETE cancella. Questo è **REST**.
- `new` e `edit` *mostrano* un form; `create` e `update` *ricevono* i dati del form. Per ogni operazione di scrittura servono quindi due azioni.
- `(.:format)`: lo stesso URL risponde anche in JSON → `/articles.json`.
- La colonna **Prefix** dà il nome agli helper per i link: `articles` → `articles_path` (= `/articles`), `article` → `article_path(1)` (= `/articles/1`), `edit_article` → `edit_article_path(1)`. Si usano nelle viste e nei controller al posto degli URL scritti a mano.

**Per il lavoro**: `bin/rails routes` (con `-c nome` o `-g testo` per filtrare) è il comando che userai di più per capire un progetto che non conosci. Per limitare le route: `resources :articles, only: [:index, :show]`.

## 4.4 Provarlo nel browser

```bash
bin/rails server
```

Apri <http://localhost:3000/articles>:

1. **Index** (`/articles`): tabella vuota + link "New Article".
2. **New** (`/articles/new`): form con Title, Body e Published at (cinque menu a tendina per anno, mese, giorno, ora e minuti).
3. Compilando e premendo "Create Article" parte un **POST /articles** → azione `create` → salvataggio → **redirect** (codice 302) a `/articles/1` → azione `show`.
4. **Show**: dettaglio + link Edit e Back.

Durante l'esercizio è stato creato l'articolo "Beginning Rails 6". Il log del server ha registrato:

```
POST /articles -> 302 http://localhost:3000/articles/1
```

La versione JSON funziona senza scrivere niente: <http://localhost:3000/articles.json>

```json
[{"id":1,"title":"Beginning Rails 6","body":"Il mio primo articolo creato con lo scaffold.",
  "published_at":"2026-10-01T12:00:00.000Z", ... ,"url":"http://localhost:3000/articles/1.json"}]
```

> **Il server va riavviato?** Per le modifiche in `app/` (modelli, controller, viste) no: in development Rails ricarica il codice a ogni richiesta. Va riavviato se modifichi `config/`, il `Gemfile` o file di inizializzazione.

## 4.5 Lo scaffold nel lavoro reale

⚠️ **Lo scaffold non è codice da produzione.** Serve a:
- avere subito qualcosa che gira, per verificare un'idea;
- prototipi, pannelli di amministrazione interni, demo;
- **studiare**: è un esempio "ufficiale" di come Rails si aspetta che si scriva un CRUD.

Nei progetti reali si parte spesso dallo scaffold e poi lo si modifica a mano, oppure si scrive tutto a mano copiandone la struttura. Il limite principale: se lo rigeneri, sovrascrive le tue modifiche (lo vedi al passo 5).

---

## 🧠 Domande di verifica

1. Perché `db:rollback` va prima di `destroy model`?
2. Quale azione viene eseguita con `DELETE /articles/5`? E con `GET /articles/5/edit`?
3. Perché per creare un articolo servono due azioni (`new` e `create`)?
4. Cosa restituisce `article_path(3)`?
5. Hai modificato una vista `.html.erb`: devi riavviare il server?

<details><summary>Risposte</summary>

1. Il rollback ha bisogno del file di migrazione per sapere cosa annullare.
2. `destroy` con id 5; `edit` con id 5.
3. `new` (GET) mostra il form vuoto; `create` (POST) riceve e salva i dati inviati.
4. `"/articles/3"`.
5. No, i file in `app/` vengono ricaricati automaticamente in development.

</details>
