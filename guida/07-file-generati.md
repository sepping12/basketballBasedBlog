# Passo 7 — I file generati, riga per riga

**Obiettivo**: capire il codice prodotto dallo scaffold. È il modello di riferimento per qualsiasi CRUD che scriverai.

**Nel libro**: "I file generati" (Listato 3-6).

---

> 🔄 **Aggiornamento (passo 9)**: dopo la grafica, le viste sono diverse da quelle mostrate qui (classi CSS, testi in italiano, `datetime_local_field` al posto di `datetime_select`, messaggio flash spostato nel layout). Nel controller sono cambiati solo `index` (`Article.recent`) e i testi delle `notice`. **La struttura e i concetti spiegati in questo file restano identici.**

## 7.1 Il percorso di una richiesta

```
Browser: GET /articles/1
   │
   ▼
config/routes.rb         resources :articles  →  articles#show, params[:id] = "1"
   │
   ▼
ArticlesController       before_action :set_article  →  @article = Article.find("1")
   │                     def show; end   (vuoto: basta la variabile preparata sopra)
   ▼
Article (modello)        SELECT * FROM articles WHERE id = 1
   │
   ▼
app/views/articles/show.html.erb    usa @article per costruire l'HTML
   │
   ▼
app/views/layouts/application.html.erb   avvolge la vista (<html>, <head>, ... <%= yield %>)
   │
   ▼
Browser: riceve la pagina
```

Questo è **MVC**: il **M**odello parla col DB, il **C**ontroller coordina, la **V**ista produce l'HTML.

## 7.2 Il controller

[app/controllers/articles_controller.rb](../app/controllers/articles_controller.rb)

> ℹ️ Il tuo controller ha qualche piccola differenza rispetto al Listato 3-6 del libro: `%i[ ... ]`, `status: :unprocessable_entity` e `status: :see_other`. Il generatore di Rails 6.0.6 (più recente di quello usato nel libro) ha ricevuto questi miglioramenti, che sono spiegati sotto. La logica è identica.

```ruby
class ArticlesController < ApplicationController
  before_action :set_article, only: %i[ show edit update destroy ]
```

- `before_action`: prima di eseguire `show`, `edit`, `update` e `destroy`, chiama `set_article`. Quelle quattro azioni lavorano su **un** articolo già esistente, che va cercato. Scrivere la ricerca una volta sola evita di ripeterla quattro volte (principio **DRY**, *Don't Repeat Yourself*).
- `%i[ show edit ... ]` = `[:show, :edit, ...]`: una scorciatoia Ruby per scrivere un array di simboli.

```ruby
  # GET /articles or /articles.json
  def index
    @articles = Article.all
  end
```

- I commenti indicano la route che porta qui.
- `Article.all` = tutti gli articoli (`SELECT * FROM articles`).
- La **@** è importante: le variabili d'istanza (`@articles`) sono visibili nella vista; quelle locali (`articles`) no.
- Non c'è nessun `render`: Rails renderizza da solo `index.html.erb` (o `index.json.jbuilder` se l'URL finisce in `.json`).

```ruby
  def show
  end
```

Vuoto: `@article` l'ha già preparato `set_article`. Rails renderizza `show.html.erb`.

```ruby
  def new
    @article = Article.new
  end
```

Un articolo nuovo, vuoto e **non salvato**, da cui il form parte. Grazie a lui `form_with` sa che deve fare un POST a `/articles` e che il pulsante si chiama "Create Article".

```ruby
  def edit
  end
```

Vuoto: `@article` arriva da `set_article`. Il form è lo stesso di `new`, ma l'articolo esiste già, quindi `form_with` fa un PATCH a `/articles/1` e il pulsante dice "Update Article".

```ruby
  def create
    @article = Article.new(article_params)

    respond_to do |format|
      if @article.save
        format.html { redirect_to @article, notice: "Article was successfully created." }
        format.json { render :show, status: :created, location: @article }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @article.errors, status: :unprocessable_entity }
      end
    end
  end
```

- `Article.new(article_params)`: costruisce l'articolo con i dati del form (filtrati, vedi sotto).
- `respond_to do |format|`: risposte diverse per HTML (browser) e JSON (API).
- **Successo, HTML**: `redirect_to @article` porta a `/articles/<id>`. `notice:` è un messaggio **flash**: sopravvive al redirect e viene mostrato una volta sola da `<p id="notice"><%= notice %></p>` in `show.html.erb`.
- **Successo, JSON**: codice 201 Created.
- **Fallimento**: `render :new` mostra di nuovo il form **senza redirect**, così `@article` conserva i dati e gli errori. Il codice 422 *Unprocessable Entity* dice "i dati inviati non sono validi" (nel libro manca: lì restituiva 200).

> **`redirect_to` vs `render`** (domanda classica da colloquio):
> - `redirect_to` dice al browser "vai a quest'altro URL": parte una **nuova** richiesta e le variabili `@` si perdono.
> - `render` usa un template **nella stessa richiesta**: le variabili `@` restano.
> - Dopo un salvataggio riuscito → `redirect_to` (se ricarichi la pagina, il form non viene reinviato: è il pattern *Post/Redirect/Get*). Dopo un errore → `render`.

```ruby
  def update
    respond_to do |format|
      if @article.update(article_params)
        format.html { redirect_to @article, notice: "Article was successfully updated." }
        ...
      else
        format.html { render :edit, status: :unprocessable_entity }
        ...
```

Come `create`, ma `@article.update(...)` assegna i nuovi valori e salva in un colpo, validazioni comprese.

```ruby
  def destroy
    @article.destroy

    respond_to do |format|
      format.html { redirect_to articles_path, status: :see_other, notice: "Article was successfully destroyed." }
      format.json { head :no_content }
    end
  end
```

- Cancella e torna all'elenco (`articles_path` = `/articles`).
- `status: :see_other` (303) dice al browser di andare alla pagina successiva con un GET. Senza, alcuni browser ripeterebbero il DELETE.
- `head :no_content` (204): per l'API, risposta senza corpo.

```ruby
  private
    def set_article
      @article = Article.find(params[:id])
    end
```

- `private`: i metodi sotto **non sono azioni**, quindi non sono raggiungibili da un URL.
- `params[:id]` contiene il pezzo `:id` dell'URL.
- `find` non trova l'id? Solleva `ActiveRecord::RecordNotFound`, che Rails trasforma in una pagina **404**.

```ruby
    def article_params
      params.require(:article).permit(:title, :location, :excerpt, :body, :published_at)
    end
end
```

Sono gli **strong parameters**, fondamentali per la sicurezza:
- `require(:article)`: i dati devono arrivare dentro la chiave `article` (il form invia `article[title]`, `article[body]`, ...);
- `permit(...)`: accetta **solo** questi campi, scarta tutto il resto.

Senza `permit`, un utente malintenzionato potrebbe aggiungere al form un campo nascosto `article[admin]=true` o `article[user_id]=5` e modificare colonne che non dovrebbe toccare (*mass assignment*).

## 7.3 Le viste

### `index.html.erb` (estratto)

```erb
<p id="notice"><%= notice %></p>
...
<% @articles.each do |article| %>
  <tr>
    <td><%= article.title %></td>
    ...
    <td><%= link_to 'Show', article %></td>
    <td><%= link_to 'Edit', edit_article_path(article) %></td>
    <td><%= link_to 'Destroy', article, method: :delete, data: { confirm: 'Are you sure?' } %></td>
  </tr>
<% end %>
...
<%= link_to 'New Article', new_article_path %>
```

- `<% %>` esegue Ruby **senza stampare** (cicli, if); `<%= %>` esegue e **stampa** il risultato.
- `<%= %>` fa l'*escape* dell'HTML in automatico: se un titolo contiene `<script>`, viene mostrato come testo e non eseguito. È la protezione da **XSS**.
- `link_to 'Show', article`: Rails trasforma l'oggetto nell'URL `/articles/1`.
- `method: :delete`: i link HTML possono fare solo GET. Rails, con JavaScript (rails-ujs), trasforma il click in un form che invia `_method=delete`. `data: { confirm: ... }` mostra il popup di conferma.

### `new.html.erb` ed `edit.html.erb`

```erb
<h1>New Article</h1>
<%= render 'form', article: @article %>
<%= link_to 'Back', articles_path %>
```

Entrambe usano `render 'form'`, che include il **partial** `_form.html.erb`: i file che iniziano con `_` sono pezzi riutilizzabili. Il form è scritto una volta sola e usato in due pagine (DRY).

### `_form.html.erb` (estratto)

```erb
<%= form_with(model: article, local: true) do |form| %>
  <% if article.errors.any? %>
    <div id="error_explanation">
      <h2><%= pluralize(article.errors.count, "error") %> prohibited this article from being saved:</h2>
      <ul>
        <% article.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="field">
    <%= form.label :title %>
    <%= form.text_field :title %>
  </div>
  ...
  <%= form.datetime_select :published_at %>
  <%= form.submit %>
<% end %>
```

- `form_with(model: article)`: se `article` è nuovo → POST `/articles`; se esiste → PATCH `/articles/1`. `local: true` = invio normale (non AJAX).
- **Qui vengono mostrati gli errori di validazione** del passo 6: `article.errors.full_messages`.
- `pluralize(2, "error")` → "2 errors".
- `form.text_field :title` produce `<input name="article[title]">`: ecco perché nel controller serve `require(:article)`.
- `datetime_select` produce i 5 menu, inviati come `published_at(1i)` ... `published_at(5i)`. Rails li rimette insieme in una data.
- `form_with` aggiunge da solo un campo nascosto `authenticity_token` (vedi 7.4).

### Le viste JSON (`*.json.jbuilder`)

Sono come le viste HTML, ma producono JSON. Ecco perché `/articles.json` funziona senza scrivere codice.

## 7.4 Una cosa scoperta durante l'esercizio: il token CSRF

Durante le prove fatte da terminale con `curl`, una richiesta DELETE è stata rifiutata:

```
DELETE /articles/3 -> 422
```

e nel log del server (`log/development.log`):

```
Can't verify CSRF token authenticity.
Completed 422 Unprocessable Entity
```

Il token inviato non apparteneva più alla sessione corrente. Con un token valido, la stessa richiesta ha funzionato:

```
DELETE /articles/3 -> 303 http://localhost:3000/articles
```

**Cos'è il CSRF?** (*Cross-Site Request Forgery*.) Un sito malevolo potrebbe contenere un form nascosto che invia un DELETE al tuo blog mentre sei loggato. Rails lo impedisce così:
- ogni form contiene un `authenticity_token` nascosto, legato alla sessione dell'utente;
- ogni richiesta POST/PATCH/DELETE senza un token valido viene rifiutata con 422.

Nel browser non te ne accorgi: `form_with`, `link_to ... method: :delete` e `<%= csrf_meta_tags %>` nel layout se ne occupano da soli.

**Per il lavoro**: se vedi "Can't verify CSRF token authenticity" nel log, è quasi sempre una di queste cause:
- un form scritto a mano in HTML, senza `form_with`;
- una chiamata JavaScript/fetch che non invia l'header `X-CSRF-Token`;
- una sessione scaduta.

Le API JSON pure (senza sessione, con token di autenticazione) di solito disattivano questo controllo.

## 7.5 I test generati

Lo scaffold ha generato anche i test. Lanciati con:

```bash
bin/rails test
```

```
7 runs, 9 assertions, 0 failures, 0 errors, 0 skips
```

Tutti verdi: le 7 azioni del controller funzionano. I test usano `db/test.sqlite3` e i dati finti di `test/fixtures/articles.yml`. Il Capitolo 16 li spiega.

## 7.6 Esercizi per esplorare (consigliati dal libro)

Prova da solo, con il server avviato:

1. Cambia il messaggio `"Article was successfully created."` in italiano nel controller e crea un articolo. (Non serve riavviare il server.)
2. In `show.html.erb` sposta il titolo dentro un `<h1>`.
3. In `index.html.erb` togli la colonna Body.
4. Apri `/articles/999`: cosa succede? (`set_article` → `find` → `RecordNotFound`.)
5. Togli `:excerpt` da `permit` e prova a salvare un excerpt. Poi guarda il log: compare `Unpermitted parameter: :excerpt`. Ricordati di rimetterlo!
6. Apri `bin/rails console` e prova: `Article.count`, `Article.first`, `Article.where(location: "Bowling Green, KY")`.

Se rompi qualcosa, puoi rigenerare lo scaffold (passo 5.3) oppure chiedere aiuto.

---

## 🧠 Domande di verifica

1. Perché `show` ed `edit` sono vuote ma funzionano?
2. Differenza tra `@articles` e `articles` nel controller?
3. Quando si usa `redirect_to` e quando `render`?
4. A cosa serve `permit` e cosa succede senza?
5. Come fa lo stesso `_form.html.erb` a creare in `new` e ad aggiornare in `edit`?
6. Differenza tra `<% %>` e `<%= %>`?
7. Cosa vuol dire "Can't verify CSRF token authenticity"?

<details><summary>Risposte</summary>

1. `before_action :set_article` prepara `@article` e Rails renderizza da solo il template con il nome dell'azione.
2. Solo la variabile con `@` è visibile nella vista.
3. `redirect_to` dopo un salvataggio riuscito (nuova richiesta); `render` dopo un errore (stessa richiesta, dati ed errori conservati).
4. Accetta solo i campi elencati. Senza, l'utente potrebbe modificare colonne che non dovrebbe (mass assignment). In Rails, senza `permit` il salvataggio solleva `ForbiddenAttributesError`.
5. `form_with(model: article)` guarda se l'oggetto è già salvato: nuovo → POST a `/articles`, esistente → PATCH a `/articles/:id`.
6. `<% %>` esegue senza stampare; `<%= %>` esegue e stampa (con escape HTML).
7. La richiesta non contiene un token anti-CSRF valido per la sessione corrente, quindi Rails la rifiuta (422).

</details>
