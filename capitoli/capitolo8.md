# Capitolo 8 — Action Pack avanzato

> 🔄 **Aggiornamento (Capitolo 11)**: il testo dell'articolo è ora un **rich text** (Action Text): la sanificazione dell'HTML che qui è descritta con `simple_format` la fa ora Action Text quando mostra `article.body`. Il resto è invariato.

> 🔄 **Aggiornamento (Capitolo 9)**: il form dei commenti non è più sempre visibile nella pagina dell'articolo: si carica **a richiesta, via Ajax**, e commenti e relativa eliminazione avvengono senza ricaricare la pagina. Le route dei commenti ora includono anche `:new`, e i test sono **102**. Il resto del capitolo (login, filtri, proprietà, escape) è invariato.

> **In una frase**: il blog diventa un'applicazione **multiutente**: ci si registra, si fa login (con le **sessioni**), si commentano gli articoli (con le **risorse annidate**) e si proteggono le azioni con i **filtri**, in modo che ognuno modifichi solo ciò che è suo.

## 1. Il contesto (la mappa mentale)

Fino al Capitolo 7 chiunque poteva fare tutto. Ora servono due concetti diversi, che spesso si confondono:

| | Domanda | Come si risolve nel blog |
|---|---|---|
| **Autenticazione** | *Chi sei?* | `User.authenticate` + sessione (`session[:user_id]`) + filtro `authenticate` |
| **Autorizzazione** | *Puoi farlo?* | si cerca sempre **tra le cose dell'utente**: `current_user.articles.find(id)` |

**Chi può fare cosa** (verificato con richieste vere nello script e nei test):

| Azione | Visitatore | Utente loggato | Autore dell'articolo |
|---|:-:|:-:|:-:|
| Leggere elenco e articoli | ✅ | ✅ | ✅ |
| Commentare un articolo pubblicato | ✅ | ✅ | ✅ |
| Registrarsi / fare login | ✅ | — | — |
| Scrivere un nuovo articolo | ❌ → login | ✅ | ✅ |
| Modificare / eliminare un articolo | ❌ → login | ❌ (404) | ✅ |
| Eliminare i commenti dell'articolo | ❌ → login | ❌ (404) | ✅ |
| Vedere le email dei commentatori | ❌ | ❌ | ✅ |
| Modificare i propri dati (email, password) | ❌ → login | ✅ | ✅ |

Il flusso del login:

```
GET /articles/new          (visitatore)  →  filtro authenticate  →  302 /login   (+ ricorda: session[:return_to] = "/articles/new")
POST /session  (email, pwd)              →  User.authenticate(...)  →  reset_session; session[:user_id] = user.id
                                          →  302 alla pagina voluta   (flash: "Accesso effettuato.")
GET /articles/new          (loggato)    →  current_user = User.find_by(id: session[:user_id])  →  200
DELETE /logout                           →  reset_session  →  302 /
```

## 2. Cosa ho fatto

**Comandi (come nel libro):**

```bash
bin/rails g controller users --no-assets --no-helper       # + comments e sessions
```

**Codice scritto** (tutto verificato; 92 test, tutti verdi):

| File | Cosa contiene |
|---|---|
| `config/routes.rb` | `resources :comments` **annidato** negli articoli; `resources :users`; `resource :session`; `/login` e `/logout` |
| `app/controllers/application_controller.rb` | `current_user`, `logged_in?`, filtro `authenticate`, `access_denied` |
| `users_controller.rb` | registrazione (`new`/`create`) e modifica dei propri dati (`edit`/`update`) |
| `sessions_controller.rb` | login (`create`) e logout (`destroy`) |
| `comments_controller.rb` | `create` (chiunque) e `destroy` (solo l'autore dell'articolo) |
| `articles_controller.rb` | filtri, `current_user.articles.find/new`, `category_ids: []` nei permit |
| `app/models/article.rb` | `belongs_to :user` di nuovo **obbligatorio**; metodo `owned_by?(utente)` |
| `app/helpers/application_helper.rb` | `submit_or_cancel` (pulsante + link "Annulla") |
| Viste | `users/{new,edit,_form}`, `sessions/new`, `comments/{_comment,_form}`, `articles/show` (con i commenti), `_form` (categorie), navbar e flash `alert` nel layout |
| `blog.css` | chip e checkbox delle categorie, commenti, avviso di errore |
| Test | `sessions_`, `users_`, `comments_controller_test.rb` + `articles_controller_test.rb` riscritto (92 totali) |
| Script | [capitolo8_esercizi.rb](capitolo8_esercizi.rb) → `bin/rails runner capitoli/capitolo8_esercizi.rb` |

Gli script dei capitoli 6 e 7 sono stati adattati (ora un articolo ha sempre un autore) e girano ancora.

### Dove ho deviato dal libro (e perché)

| Cosa | Libro | Qui | Motivo |
|---|---|---|---|
| Route `users` | `resources :users` (7 azioni) | `only: [:new, :create, :edit, :update]` | le altre azioni non esistono: una route senza azione dà errore |
| Route `comments` | tutte e 7 | `only: [:create, :destroy]` | gli altri metodi non servono |
| **Logout** | `get "/logout"` | **`delete "/logout"`** | una GET non deve **mai** modificare lo stato (lo dice il Capitolo 7 stesso): un'immagine con `src="/logout"` ti sloggherebbe |
| Dopo il login | torna alla root | torna **alla pagina richiesta** (`session[:return_to]`) | se clicchi "Scrivi" da non loggato, dopo il login atterri sul form |
| `reset_session` al login | assente | **presente** | cambia l'id di sessione: protegge dalla *session fixation* |
| Metodi `current_user` ecc. | pubblici | **privati** (`helper_method` li rende visibili alle viste) | i metodi pubblici del controller sono potenziali azioni |
| `access_denied` | `redirect_to(...) and return false` | `redirect_to ...` | in Rails 5+ è il redirect a fermare la richiesta, non il `false` |
| Commento non valido | redirect con "Unable to add comment" | **ri-mostra la pagina** (422) con errori e testo già scritto | non si perde quello che l'utente ha digitato |
| Email dei commenti | mostrate ("Nome <email> said:") | visibili **solo all'autore dell'articolo** | pubblicare le email dei visitatori è un problema di privacy |
| `_article.html.erb` | mostra l'articolo intero (show + index) | resta la **card** dell'elenco; `show` ha il suo layout | il blog ha un design proprio |
| Link Elimina | `confirm: '...'` | `data: { confirm: '...' }` | `confirm:` non funziona più dalle versioni 4 di Rails (il libro è sbagliato su questo punto) |
| `submit_or_cancel` | link a `javascript:history.go(-1)` | link a un **percorso esplicito** | niente URL `javascript:` (non funzionano con la CSP) |
| Dopo la registrazione | alla lista articoli | alla pagina di login, con messaggio | l'utente deve poi accedere |
| `users#update` | `current_user` | `User.find(current_user.id)` | se l'aggiornamento fallisce, la navbar non mostra un'email non salvata |
| CSS | ~200 righe da scaricare | il **tuo tema** (già fatto nel passo 9) | `scaffolds.scss` era già stato eliminato |
| Testi | inglese | italiano | coerenza col sito |

## 3. I concetti chiave

### 3.1 Risorse annidate

I commenti non hanno senso senza articolo, quindi i loro URL **contengono** l'id dell'articolo:

```ruby
resources :articles do
  resources :comments, only: [:create, :destroy]
end
```

| Verbo | URL | Helper | Azione |
|---|---|---|---|
| POST | `/articles/5/comments` | `article_comments_path(5)` | `comments#create` |
| DELETE | `/articles/5/comments/9` | `article_comment_path(5, 9)` | `comments#destroy` |

Il controller trova **sempre** prima l'articolo (`before_action :load_article`, con `params[:article_id]`) e lavora sui commenti **di quell'articolo**: non può toccare quelli altrui.

### 3.2 `resource` (singolare) vs `resources`

| | `resources :articles` | `resource :session` |
|---|---|---|
| Azioni | 7 (c'è `index`) | 6 (**niente `index`**) |
| URL | `/articles/:id` | `/session` (**senza `:id`**) |
| Nomi | plurali (`articles_path`) | singolari (`session_path`) |
| Quando | una collezione di cose | una cosa sola (la tua sessione, il tuo profilo) |

Il controller resta al plurale (`SessionsController`). **Login = creare una sessione** (POST), **logout = distruggerla** (DELETE): sessione trattata come risorsa REST.

### 3.3 Sessioni e cookie

HTTP non ha stato: ogni richiesta è "al buio". Rails lo simula con un **cookie**: il browser lo rimanda a ogni richiesta e Rails ci ritrova i dati di sessione. `session` è un hash, come `flash` (che è una sessione che scade da sola).

Verificato:
- al primo accesso Rails imposta il cookie `_blog_session`;
- il cookie è **cifrato**: non contiene la stringa `user_id` in chiaro;
- dopo il login il cookie **cambia** (`reset_session`);
- in sessione si salva **solo l'id** (`session[:user_id]`), non l'oggetto: un oggetto in sessione diventerebbe "stantio" se l'utente cambiasse.

### 3.4 Login e logout

```ruby
def create
  if (user = User.authenticate(params[:email], params[:password]))   # assegno e controllo in un colpo
    destinazione = session[:return_to]
    reset_session                                  # nuova sessione al login
    session[:user_id] = user.id
    redirect_to(destinazione || root_path, notice: "Accesso effettuato.")
  else
    flash.now[:alert] = "Email o password non corretti."             # valido solo per QUESTA risposta
    render :new, status: :unprocessable_entity
  end
end

def destroy
  reset_session            # azzera TUTTO (più sicuro che togliere solo user_id)
  redirect_to root_path, notice: "Sei uscito."
end
```

- **`flash` vs `flash.now`**: `flash` sopravvive al redirect successivo; `flash.now` vale solo per la risposta corrente (qui non c'è redirect, c'è un `render`).
- Un **errore generico** ("Email o password non corretti") sia per password sbagliata sia per email inesistente: verificato che i due casi danno lo stesso messaggio, così non si scopre quali email sono registrate.
- `new` non ha un metodo: basta il template `sessions/new.html.erb` e Rails lo renderizza.
- Il form di login non ha un modello: `form_with(url: session_path, ...)`.

### 3.5 `current_user` e `helper_method`

```ruby
helper_method :current_user, :logged_in?

def current_user
  return unless session[:user_id]
  @current_user ||= User.find_by(id: session[:user_id])    # una query sola per richiesta (memoizzazione)
end
```

`helper_method` rende questi metodi chiamabili **anche dalle viste** (`<% if logged_in? %>` nella navbar). Con `find_by` (non `find`): se l'utente è stato eliminato, restituisce `nil` invece di sollevare un errore.

### 3.6 I filtri (`before_action`)

Codice eseguito **prima** di un'azione:

```ruby
before_action :authenticate, except: [:index, :show]    # per tutte TRANNE queste
before_action :authenticate, only: :destroy              # SOLO per queste
skip_before_action :authenticate                         # in una sottoclasse: salta quello ereditato
```

Verificato per `ArticlesController`: `index` e `show` → 200 per tutti; `new`, `create`, `edit`, `update`, `destroy` da visitatore → **302 a `/login`** con l'avviso "Accedi per continuare." (e nessun articolo creato).

⚠️ **Aggiornamento rispetto al libro**: dice che un `before_action` che restituisce `false` ferma l'azione. **Non è più vero dal Rails 5**: la richiesta si ferma solo se il filtro fa un **`redirect_to` o un `render`**.

### 3.7 Autorizzazione: cercare tra le cose dell'utente

```ruby
@article = current_user.articles.find(params[:id])   # invece di Article.find(params[:id])
```

Se l'articolo non è dell'utente, `find` solleva `RecordNotFound` → **404** (verificato: un altro utente loggato riceve 404 su `edit`, `update` e `destroy` forzando l'URL). Senza che serva scrivere un `if`: la sicurezza sta nella **forma della ricerca**.

Lo stesso per creare: `current_user.articles.new(article_params)` imposta da solo `user_id`. E se qualcuno prova a passare un `user_id` nel form? Viene scartato dagli strong parameters (verificato: nel log `Unpermitted parameter: :user_id`, e l'autore resta quello loggato).

**Nascondere un link non è sicurezza.** `owned_by?` serve a mostrare Modifica/Elimina solo all'autore (esperienza utente), ma la protezione vera è nel controller. Verificato: anche forzando l'URL, 404.

```ruby
def owned_by?(owner)
  return false unless owner.is_a?(User)    # nil o altro → false (visitatori inclusi)
  user == owner
end
```

### 3.8 Categorie nel form

```erb
<%= form.collection_check_boxes(:category_ids, Category.all, :id, :name) do |b| %>
  <%= b.label(class: "check") { b.check_box + b.text } %>
<% end %>
```

```ruby
params.require(:article).permit(:title, ..., category_ids: [])    # "un array di id"
```

I 4 argomenti: l'attributo (`:category_ids`), i valori possibili (`Category.all`), cosa salvare (`:id`), cosa mostrare (`:name`). `category_ids` e `category_ids=` esistono grazie a `has_and_belongs_to_many` (Capitolo 6). Se non scrivi `category_ids: []` nei permit, le categorie vengono **scartate in silenzio**.

### 3.9 Escape dell'HTML (protezione dall'XSS)

Un utente potrebbe scrivere `<script>…</script>` nel titolo, nel testo o in un commento. Se la pagina lo eseguisse, un visitatore eseguirebbe codice altrui (**XSS**). Rails ti protegge di default (verificato):

| Codice | Risultato |
|---|---|
| `<%= testo %>` con `<b>ciao</b>` | `&lt;b&gt;ciao&lt;/b&gt;` → mostrato come **testo** |
| `<%= testo.html_safe %>` | `<b>ciao</b>` → **eseguito**: pericoloso, da non usare su dati degli utenti |
| `simple_format("Ciao <script>alert('xss')</script> <b>vero</b>")` | `<p>Ciao alert('xss') <b>vero</b></p>`: toglie i tag pericolosi, tiene quelli innocui (`<b>`) |

Nel blog: il **titolo** viene escapato (`&lt;script&gt;…`), il **corpo** passa da `simple_format` (che sanifica), i **commenti** idem. Verificato con un articolo il cui titolo e testo contengono `<script>`: nella pagina non compare mai `<script>alert`.

`simple_format` trasforma anche il testo semplice in HTML: riga vuota = nuovo paragrafo (`<p>`), a capo = `<br />`.

### 3.10 Gli helper di Action View

| Tipo | Esempi verificati |
|---|---|
| **URL** | `link_to 'New', '/articles/new', id: 'new_article_link'` → `<a id="new_article_link" href="/articles/new">New</a>`. Il secondo argomento può essere una stringa, una named route, un hash o **un oggetto** (diventa la sua `show`: `/articles/9`) |
| **Numeri** | `number_to_currency(1234.5, unit: '€', separator: ',', delimiter: '.', format: '%n %u')` → `"1.234,50 €"`; `number_to_percentage(66.666, precision: 1)` → `"66.7%"`; `number_to_human_size(2_500_000)` → `"2.38 MB"` |
| **Testo** | `truncate(testo, length: 20)`, `pluralize(3, 'commento', 'commenti')` → `"3 commenti"`, `simple_format`, `time_ago_in_words` |

**Helper personalizzato.** Se copi lo stesso codice di vista in più template, estrailo in un helper:

```ruby
def submit_or_cancel(form, label, cancel_path)
  safe_join([form.submit(label, class: "btn btn--primary btn--lg"),
             link_to("Annulla", cancel_path, class: "link-more")], " ")
end
```

Usato in tutti i form (articoli, utenti). `safe_join` unisce i pezzi mantenendoli "sicuri" per l'HTML.

## 4. Sicurezza: cosa c'è, cosa manca

| Argomento | Stato |
|---|---|
| **CSRF** | ✅ ogni form ha il token (`form_with`); il logout è un DELETE |
| **Session fixation** | ✅ `reset_session` al login |
| **Cookie di sessione** | ✅ cifrato (si decifra con `secret_key_base`, nelle *credentials*) |
| **User enumeration** | ✅ stesso errore per email sbagliata e password sbagliata |
| **XSS** | ✅ escape automatico + `simple_format` |
| **Mass assignment** | ✅ strong parameters |
| **Autorizzazione** | ✅ `current_user.articles.find`; email dei commentatori riservate |
| **Password** | ⚠️ SHA1 senza sale (come nel libro): **da sostituire con `has_secure_password` + bcrypt** prima di un uso reale |
| **Registrazione aperta** | ⚠️ chiunque può registrarsi e quindi **scrivere articoli** (è il modello multiutente del libro). Per un blog personale potresti volerla chiudere: togli il link "Registrati" e la route `new`/`create` |
| **Limite ai tentativi di login** | ❌ manca: un attaccante può provare molte password (si risolve con `rack-attack`) |
| **Spam nei commenti** | ❌ manca (nessun captcha né moderazione) |
| **Utente di prova** | ⚠️ `mary@example.com` / `guessit` esiste nel seed: **da eliminare** prima di mettere il sito online |

## 5. Trappole e scoperte

| Cosa | Spiegazione |
|---|---|
| Il campo **Password** del login era senza stile | trovato guardando uno screenshot: il CSS copriva solo `input[type=text]`. Ora anche `password` ed `email` |
| `confirm:` nel link | funziona solo con `data: { confirm: … }` (il libro usa una sintassi vecchia) |
| `before_action` che restituisce `false` | non ferma più nulla (Rails 5+): serve un redirect/render |
| `@article.comments.new` nel controller | aggiunge un commento **non salvato** alla lista dell'articolo, che poi verrebbe stampato: uso `Comment.new` + `comment.article = @article` |
| `link_to ... method: :delete` | richiede JavaScript (`rails-ujs`) |
| Un id nell'URL di `users/:id/edit` | viene **ignorato**: si modifica sempre se stessi (nel test: patch su un altro id modifica l'utente loggato) |
| Eliminare un utente con `dependent: :nullify` | i suoi articoli diventano **orfani** (`user_id` nullo) e nessuno potrà più modificarli |
| Tutti e 4 gli articoli di esempio sono di `mary` | per modificarli devi accedere come `mary`, oppure riassegnarli (vedi sotto) |
| Per i test | `log_in_as(utente)` fa un login vero (`POST /session`): niente scorciatoie |

## 6. Come provarlo

```bash
bin/rails server
```

1. **Registrati** su <http://localhost:3000/users/new> (email valida, password di 4-20 caratteri).
2. **Accedi** su `/login`, poi **Scrivi** un articolo scegliendo qualche categoria.
3. Apri l'articolo in una **finestra privata** (da visitatore): lascia un **commento**. Poi, da loggato, vedrai l'email e **Elimina** accanto al commento.
4. Prova a forzare `/articles/ID/edit` per un articolo di un altro utente: **404**.

Gli articoli di esempio sono di `mary@example.com` (password `guessit`). Per intestarli a te:

```bash
bin/rails runner 'u = User.find_by(email: "tua@email.it"); Article.update_all(user_id: u.id)'
```

Poi elimina l'utente di prova: `bin/rails runner 'User.find_by(email: "mary@example.com")&.destroy'`.

Test e prove: `bin/rails test` (92) e `bin/rails runner capitoli/capitolo8_esercizi.rb`.

## 7. Checklist del capitolo

- [x] `rails g controller users` e azioni `new`, `create`, `edit`, `update`
- [x] Form utente con `password_field` e strong parameters
- [x] Risorse annidate: comments dentro articles; `create` e `destroy`
- [x] Pagina articolo con commenti e form (partial `_comment`, `render @article.comments`)
- [x] Flash `notice` e `alert` nel layout
- [x] Sessioni e cookie; `resource :session`; login e logout; `flash.now`; `reset_session`
- [x] Filtri: `before_action`, `only`, `except`; `current_user`, `logged_in?`, `helper_method`
- [x] Protezione di articoli, utenti e commenti; ricerca tramite `current_user.articles`
- [x] `owned_by?` e controlli visibili solo all'autore
- [x] Categorie nel form (`collection_check_boxes`, `category_ids: []`)
- [x] Escape dell'HTML, `simple_format`, `html_safe`
- [x] Helper di Action View e helper personalizzato (`submit_or_cancel`)
- [x] Stile (con il tema del blog)
- [x] 92 test; script con le prove

## 8. Auto-verifica

1. Che differenza c'è tra autenticazione e autorizzazione? Dove le trovi nel blog?
2. Perché in sessione si salva `user.id` e non l'oggetto `user`?
3. Perché `current_user.articles.find(params[:id])` è più sicuro di `Article.find(params[:id])`?
4. Perché il logout è un `DELETE` e non una `GET`?
5. Differenza tra `flash` e `flash.now`?
6. Cosa succede se dimentichi `category_ids: []` nei `permit`?
7. Perché `<%= testo %>` è sicuro e `<%= testo.html_safe %>` no?

<details><summary>Risposte</summary>

1. Autenticazione = *chi sei* (login, sessione, filtro `authenticate`). Autorizzazione = *cosa puoi fare* (`current_user.articles.find`, `owned_by?`).
2. Un oggetto in sessione diventerebbe obsoleto se l'utente cambia (email, ecc.); l'id basta per ricaricarlo fresco a ogni richiesta.
3. Se l'articolo non è dell'utente, `find` non lo trova e solleva `RecordNotFound` (404): non serve scrivere un controllo, e non si può dimenticare.
4. Una GET non deve modificare lo stato: un link o un'immagine su un altro sito potrebbe sloggare l'utente.
5. `flash` sopravvive al redirect successivo; `flash.now` vale solo per la risposta corrente (con `render`).
6. Le categorie scelte nel form vengono scartate in silenzio e l'articolo si salva senza.
7. `<%= %>` fa l'escape: l'HTML diventa testo. `html_safe` dice "è già sicuro" e lo stampa così com'è: un `<script>` verrebbe eseguito.

</details>

---

**Prossimo capitolo**: il **9** tratta come Rails gestisce **JavaScript e CSS** (Webpacker, asset pipeline), e come rendere il sito più dinamico (anche i form con Ajax, rimandati dal libro).
