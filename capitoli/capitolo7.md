# Capitolo 7 — Action Pack: route, controller e viste

> 🔄 **Aggiornamento (Capitolo 8)**: da quel capitolo per creare, modificare o eliminare articoli serve il **login**, e l'autore di un articolo è sempre l'utente loggato. Gli esempi di questo capitolo (e lo script) sono stati adattati; dove leggi di richieste senza login o di `user_id` a `nil`, descrive lo stato di allora.

> **In una frase**: Action Pack è la parte di Rails che gestisce il **ciclo di richiesta**: dall'URL digitato nel browser alla pagina HTML di risposta. Il capitolo spiega come **route**, **controller**, **viste**, **layout**, **form** e **partial** collaborano.

## 1. Il contesto (la mappa mentale)

Nei capitoli 5-6 hai lavorato sul **modello** (M). Qui entrano gli altri due pezzi di MVC. Action Pack ne contiene tre:

| Componente | Cosa fa | Dove vive nel blog |
|---|---|---|
| **Action Dispatch** | il **routing**: dato un URL + un verbo HTTP, decide quale controller e azione chiamare | `config/routes.rb` |
| **Action Controller** | esegue la logica, parla con i modelli, sceglie la risposta | `app/controllers/` |
| **Action View** | produce l'HTML (template ERB, helper, partial, layout) | `app/views/`, `app/helpers/` |

**Il ciclo di richiesta**, che ho percorso con richieste vere (verificate nello script):

```
1. Il browser chiede  GET /articles/5
2. ROUTE        routes.rb: "resources :articles"  →  articles#show, params[:id] = "5"
3. CONTROLLER   ArticlesController: before_action set_article → @article = Article.find("5")
4. MODELLO      Article → SELECT ... WHERE id = 5
5. VISTA        articles/show.html.erb (usa @article), inserita nel LAYOUT al posto di <%= yield %>
6. RISPOSTA     HTML con status 200   (oppure un redirect, o un errore)
```

Il filo conduttore: **ogni livello ha un solo compito**. La vista non cerca dati, il controller non scrive HTML, il modello non sa niente del web.

## 2. Cosa ho fatto

Il capitolo è una "passeggiata guidata" nel codice che lo scaffold ha già generato nel Capitolo 3: ci sono pochi comandi da lanciare e molto da capire. Per **verificare** ogni affermazione del libro ho fatto tre cose.

**1) Script con le prove** → [capitolo7_esercizi.rb](capitolo7_esercizi.rb)

```bash
bin/rails runner capitoli/capitolo7_esercizi.rb
```

Fa richieste web vere (GET, POST, PATCH, DELETE) dentro il programma, attraverso route, controller, vista e layout del blog, e mostra status, redirect, flash, parametri e log. Gira in una transazione annullata: i tuoi articoli restano com'erano.

**2) Una modifica al blog: il partial segue la convenzione.** `app/views/articles/_card.html.erb` è diventato **`_article.html.erb`**, quindi nelle viste basta `render @articles` (prima `render partial: "articles/card", collection: @articles, as: :article`). Nell'elenco e nella home il risultato è identico.

**3) Test nuovi** (il totale era **54**, ora 92 con il Capitolo 8):
- `test/controllers/routing_test.rb`: le route (`assert_routing`, `assert_recognizes`) e le named route;
- `test/controllers/articles_controller_test.rb`, ampliato: render dentro il layout, risposta JSON, flash dopo il redirect, errori col form ri-renderizzato, strong parameters, 404, `destroy` con 303.

### Dove ho deviato dal libro

| Cosa | Libro | Qui | Motivo |
|---|---|---|---|
| `root` | `root to: "articles#index"` | resta **`root "pages#home"`** | hai la landing page; l'elenco è su `/articles` |
| Route `teams` | esempi `get '/teams/home', ...` | provate in un **RouteSet separato** nello script | non sono pagine del blog: servono a capire il routing |
| Messaggio flash | `<p class="notice">` in `show.html.erb` | nel **layout** (`.toast`), una volta per tutte le pagine | non si ripete in ogni vista |
| Codice del controller | Listato 7-4 | quello generato dal tuo Rails 6.0.6 | ha `status: :unprocessable_entity` e `:see_other` in più (vedi capitolo 3) |

## 3. I concetti chiave

### 3.1 Il controller è una classe; le azioni sono i suoi metodi **pubblici**

```ruby
class ArticlesController < ApplicationController   # ApplicationController < ActionController::Base
  def index  ...  end         # pubblico  → è un'azione, raggiungibile da un URL
  private
  def set_article  ...  end   # privato   → NON è un'azione
end
```

Verificato: `ArticlesController.action_methods` → `["create", "destroy", "edit", "index", "new", "show", "update"]`. `set_article` e `article_params` sono privati, quindi **nessun URL** può chiamarli. (Esempio del libro con il `CDPlayer`: un metodo privato dà `NoMethodError` se lo chiami da fuori.)

È ereditando da `ApplicationController` (e da `ActionController::Base`) che una classe Ruby qualunque diventa un controller. `ApplicationController` è il posto per ciò che serve a **tutti** i controller (nel Capitolo 8: il login).

**Convenzione di fine azione**: se l'azione non dice altro, Rails renderizza il template con **lo stesso nome** (`index` → `articles/index.html.erb`). Il controller passa i dati alla vista con le **variabili di istanza** (`@articles`): verificato con `app.controller.view_assigns.keys`.

### 3.2 ERB: `<% %>` e `<%= %>`

| Tag | Fa | Esempio |
|---|---|---|
| `<% codice %>` | **esegue**, non stampa | `<% @articles.each do \|a\| %>` … `<% end %>` |
| `<%= codice %>` | esegue **e stampa** (con escape HTML) | `<%= article.title %>` |

Trappola classica, verificata: `<li><% 1 + 1 %></li>` → `<li></li>` (nessun errore, ma vuoto); con `=` → `<li>2</li>`.

### 3.3 Gli helper

Piccoli metodi che tengono la vista pulita e senza logica: ce ne sono moltissimi già pronti (`link_to`, `form_with`, `pluralize`...) e ognuno ha il suo modulo (`ArticlesHelper`, `ApplicationHelper`). Quelli del blog (`nav_link`, `data_it`, `reading_time`) sono disponibili in tutte le viste.

### 3.4 Il routing

| Cosa | Esempio | Risultato verificato |
|---|---|---|
| Route semplice | `get '/teams/home', to: 'teams#index'` | `/teams/home` → `{controller: "teams", action: "index"}` |
| Parametro nell'URL | `get '/teams/search/:query', to: 'teams#search'` | `/teams/search/toronto` → `query: "toronto"` |
| **Named route** | `..., as: 'search'` | `search_path(query: 'toronto')` → `"/teams/search/toronto"`; `search_url` aggiunge host |
| URL inesistente | | `ActionController::RoutingError` (in produzione: 404) |
| **L'ordine conta** | `/teams/:nome` prima di `/teams/home` | `/teams/home` → `show` con `nome: "home"`: la prima vince |

**Named route**: brevi, DRY e resistenti ai cambiamenti (se rinomini il controller, i link non vanno toccati).

**Risorse REST: `resources :articles`.** Lo stesso URL, **verbo diverso → azione diversa** (verificato con `recognize_path`):

| Verbo | URL | Azione | Helper |
|---|---|---|---|
| GET | `/articles` | `index` | `articles_path` |
| POST | `/articles` | `create` | `articles_path` |
| GET | `/articles/new` | `new` | `new_article_path` |
| GET | `/articles/:id` | `show` | `article_path(id)` |
| GET | `/articles/:id/edit` | `edit` | `edit_article_path(id)` |
| PATCH / PUT | `/articles/:id` | `update` | `article_path(id)` |
| DELETE | `/articles/:id` | `destroy` | `article_path(id)` |

Come ispezionarle: `bin/rails routes` (con `-c articles` o `-g edit` per filtrare), oppure <http://localhost:3000/rails/info/routes> col server acceso.

**Verbi HTTP.** **GET** = leggere, non deve **mai** modificare dati. **POST** = creare. **PATCH/PUT** = modificare. **DELETE** = eliminare. I browser sanno fare solo GET e POST: per gli altri Rails invia una POST con un campo nascosto `_method` (nel form di modifica c'è `name="_method" value="patch"`, verificato).

### 3.5 `render` o `redirect_to`?

| | `render` | `redirect_to` |
|---|---|---|
| Cosa fa | mostra un template **nella stessa richiesta** | dice al browser: "vai a quest'altro URL" |
| Status verificati | **422** su create/update falliti | **302** dopo create/update, **303** dopo destroy |
| Variabili `@` | restano (il form si ripopola, con gli errori) | si perdono (nuova richiesta) |
| Quando | **dopo un errore** | **dopo un successo** (impedisce il reinvio del form ricaricando) |

`redirect_to @article` equivale a `redirect_to article_path(@article)`: un oggetto diventa il suo URL.

**Flash.** `redirect_to @article, notice: "Articolo pubblicato!"` equivale a `flash[:notice] = "..."`. Il messaggio **sopravvive a un solo redirect** e poi sparisce: verificato, la pagina dopo il redirect lo contiene, la ricarica no. È un hash: si possono usare altre chiavi (`flash[:alert]`).

**Formati.** `respond_to` sceglie la risposta secondo il formato: `/articles` → HTML, `/articles.json` → JSON. Lo scaffold fornisce quindi un'**API gratis**: verificato, `/articles.json` risponde `application/json` con le chiavi `id, title, location, excerpt, body...`.

### 3.6 I layout

Il layout (`app/views/layouts/application.html.erb`) è il guscio attorno a ogni pagina; la vista entra al posto di `<%= yield %>`. Verificato: la stessa pagina senza layout (`layout: false`) non contiene `<html`; con il layout sì, più navbar e footer.

Quale layout viene usato? La **più specifica** tra: la direttiva `layout "nome"` nel controller → un file col nome del controller (`layouts/articles.html.erb`) → quella di `ApplicationController` → **`application.html.erb`** (quasi sempre quella).

### 3.7 I form e gli helper di form

| | FormHelper | FormTagHelper |
|---|---|---|
| Legato a un modello | **sì** (si auto-popola, evidenzia gli errori) | no |
| Nomi | `form.text_field :title` | `text_field_tag :q` (finisce in `_tag`) |
| Genera | `<input name="article[title]" id="article_title">` | `<input name="q" id="q">` |

`form_with(model: article)` decide **da solo** cosa fare (verificato):

| `article` è... | `action` | metodo | Il pulsante dice |
|---|---|---|---|
| nuovo | `/articles` | POST | "Create…" (il blog: "Pubblica articolo") |
| già salvato | `/articles/5` | POST + `_method=patch` | "Update…" (il blog: "Salva le modifiche") |

Per questo `new` ed `edit` usano **lo stesso** partial `_form`. Il formato `article[title]` è ciò che permette al controller di leggere `params[:article]`. Tutti gli helper accettano un hash finale di opzioni HTML: `text_field_tag(:q, 'basket', class: 'large')` → `<input ... value="basket" class="large">`.

### 3.8 I parametri e gli strong parameters

`params` contiene tutto ciò che arriva: parametri dell'URL, della query string, del form. Dal log del server (verificato):

```
GET /articles?title=rails&body=great  →  Parameters: {"title"=>"rails", "body"=>"great"}
GET /articles/5                       →  Parameters: {"id"=>"5"}
```

**Mai passare `params` direttamente al modello.** Altrimenti un utente potrebbe aggiungere al form un campo come `admin` o `user_id`. Si filtra con gli **strong parameters**:

```ruby
params.require(:article).permit(:title, :location, :excerpt, :body, :published_at)
```

| Situazione | Risultato verificato |
|---|---|
| `Article.new(params[:article])` senza permit | `ActiveModel::ForbiddenAttributesError` |
| `.require(:article).permit(:title, :body)` | `permitted: true`, `admin` scartato |
| `.require(:nope)` (chiave assente) | `ActionController::ParameterMissing` |
| POST con `user_id` extra | il campo viene scartato (nel log: `Unpermitted parameter: :user_id`); dal Capitolo 8 l'autore è comunque l'utente loggato, non quello indicato nel form |

### 3.9 Mostrare gli errori

Quando `save` fallisce, `create` fa `render :new`: il form riappare con i dati e il blocco `#error_explanation` che itera `article.errors.full_messages`. Rails avvolge i campi errati in `<div class="field_with_errors">` (verificato): è la "maniglia" su cui il CSS colora di rosso.

### 3.10 `edit` e `update`

Simili a `new` e `create`, ma l'articolo si **cerca** invece di crearlo: lo fa il `before_action :set_article` (valido per `show`, `edit`, `update`, `destroy`). Verificato: `app.controller.view_assigns['article']` è lo stesso record, e dopo il PATCH `Processing by ArticlesController#update`. Con un titolo vuoto: **422** e nessun redirect.

### 3.11 I partial

File che iniziano con `_`, per riusare pezzi di vista (DRY). Si chiamano **senza** underscore né estensione:

| Chiamata | Cosa cerca | Locali |
|---|---|---|
| `render "form", article: @article` | `articles/_form.html.erb` | `article` |
| `render "shared/ball", size: 20` | `shared/_ball.html.erb` | `size` (verificato: `<svg ... width="20">`) |
| `render @article` | `articles/_article.html.erb` | `article` (automatica) |
| `render @articles` | `_article` **una volta per elemento** | `article` |

⚠️ `render @articles` con una **collezione vuota** restituisce `nil` (verificato): per questo nelle viste c'è `<% if @articles.any? %>`, con uno stato "nessun articolo" nell'`else`.

## 4. Trappole e scoperte

| Cosa | Spiegazione |
|---|---|
| `<%` al posto di `<%=` | non dà errore, stampa **niente** |
| 404 nei test ≠ 404 in produzione | in **test** `find` solleva `RecordNotFound` (`show_exceptions = false`); in **sviluppo e produzione** diventa una risposta 404. Nei test si scrive `assert_raises(ActiveRecord::RecordNotFound)` |
| Un'azione che modifica dati dietro una GET | mai: i crawler e i link prefetch la eseguirebbero |
| `link_to "Elimina", @article, method: :delete` | funziona solo con JavaScript (`rails-ujs`): trasforma il click in una richiesta con `_method=delete` |
| Richieste POST da `curl`/script | rifiutate con 422 se mancano il **token CSRF**; il browser lo include da solo. (Nello script lo disattivo temporaneamente) |
| Il partial `_article` ha due versioni | `_article.html.erb` (card) e `_article.json.jbuilder` (API): Rails sceglie in base al formato della richiesta |
| Email con una sola lettera prima della `@` | **trovata durante la prova**: la regex del libro (`\A[^@][\w.-]+@...`) esige almeno 2 caratteri, quindi `x@example.com` è rifiutata. Va bene per studiare; in un progetto vero si usa una regex più permissiva o la gemma `email_validator` |
| Variabili dello script e `eval` | (solo script) le variabili locali non sono visibili a `eval`: vanno passate con `local_variable_set` |

## 5. Come provarlo

```bash
bin/rails routes -c articles                       # le route
bin/rails runner capitoli/capitolo7_esercizi.rb    # tutte le prove (54 test: bin/rails test)
bin/rails server                                   # poi: /articles, /articles.json, /articles?title=rails&body=great
tail -f log/development.log                        # guarda "Parameters:" mentre usi il sito
```

## 6. Checklist del capitolo

- [x] Componenti di Action Pack e ciclo di richiesta
- [x] ERB: `<% %>` vs `<%= %>`
- [x] Controller come classe, azioni = metodi pubblici
- [x] Routing: route semplici, parametri, named route, ordine
- [x] `resources`, REST e verbi HTTP; `root`
- [x] Controller RESTful dello scaffold: variabili di istanza, `respond_to` (HTML/JSON)
- [x] `render` e `redirect_to`, flash
- [x] Template e convenzione sui nomi, layout e `yield`
- [x] Form: FormHelper vs FormTagHelper, `form_with`, nomi `article[title]`
- [x] `params` e strong parameters
- [x] Errori di validazione nel form (`field_with_errors`)
- [x] `edit`/`update` con `before_action`
- [x] Partial: variabili locali, oggetti e collezioni
- [x] Test su route e ciclo di richiesta

## 7. Auto-verifica

1. Quali metodi di un controller sono "azioni" e perché `set_article` non lo è?
2. Che URL e che verbo servono per **modificare** l'articolo 5? E per **eliminarlo**?
3. Dopo `@article.save` fallito: `render` o `redirect_to`? Perché lo status è 422?
4. A cosa serve `permit`, e cosa succederebbe passando `params[:article]` direttamente a `Article.new`?
5. Come fa `form_with(model: article)` a sapere se deve creare o modificare?
6. Che differenza c'è tra `render 'form'` e `render @articles`?

<details><summary>Risposte</summary>

1. I metodi **pubblici**. `set_article` è privato: nessun URL può chiamarlo.
2. `PATCH /articles/5` (o PUT) per modificare; `DELETE /articles/5` per eliminare. Il form le invia come POST con `_method` nascosto.
3. `render :new`, così il form si ripopola con gli errori. 422 = "Unprocessable Entity": i dati inviati non sono validi.
4. Accetta solo i campi elencati (protegge dal mass assignment). Senza `permit`: `ActiveModel::ForbiddenAttributesError`.
5. Guarda se l'oggetto è già salvato (`persisted?`): nuovo → POST a `/articles`; esistente → PATCH a `/articles/:id`.
6. `render 'form'` include un partial per nome (e gli passi tu le locali); `render @articles` deduce il partial dal tipo degli oggetti e lo ripete per ciascuno.

</details>

---

**Prossimo capitolo**: l'**8** (Action Pack avanzato) parte da zero con il controller degli utenti, aggiunge **login e sessioni** (e con esse chiude il cerchio: `Article belongs_to :user` potrà tornare obbligatorio), i **commenti** negli articoli e un po' di stile.
