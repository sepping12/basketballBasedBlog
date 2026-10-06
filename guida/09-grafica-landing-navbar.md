# Passo 9 — Grafica, landing page e navbar (il blog diventa "Fast Break")

**Obiettivo**: trasformare lo scaffold grezzo in un blog di basket presentabile: landing page, navbar, pagine articolo curate, form stilato, tutto in italiano. Qui impari anche **layout, partial, helper, content_for, seed e CSS in Rails**, cioè quello che al lavoro si tocca di continuo.

Questo passo va oltre il libro (Capitolo 3): non c'è nel PDF, è un'estensione dell'esercizio.

---

## 9.1 La mappa: cosa è stato creato e modificato

| File | Cosa fa |
|---|---|
| `config/routes.rb` | aggiunge `root "pages#home"` e `get "chi-sono"` |
| `app/controllers/pages_controller.rb` | **nuovo** controller per le pagine "statiche": `home` e `about` |
| `app/views/pages/home.html.erb` | **la landing page** |
| `app/views/pages/about.html.erb` | pagina "Chi sono" (testo di partenza da riscrivere) |
| `app/views/layouts/application.html.erb` | **layout**: navbar + footer + messaggio flash, intorno a ogni pagina |
| `app/views/shared/_ball.html.erb` | partial: il pallone in SVG, riusato ovunque |
| `app/views/articles/_card.html.erb` | partial: la "card" di anteprima di un articolo |
| `app/views/articles/{index,show,new,edit,_form}.html.erb` | ridisegnati |
| `app/helpers/application_helper.rb` | nome del blog, `nav_link`, date in italiano |
| `app/helpers/articles_helper.rb` | `article_date`, `reading_time` |
| `app/models/article.rb` | scope `latest_first` (poi arricchito nel Capitolo 6) |
| `config/locales/modelli.yml` e `errori.yml` | nomi "umani" dei campi e messaggi d'errore in italiano (nati come `articles.yml`, poi estesi nel Capitolo 6) |
| `app/assets/stylesheets/blog.css` | **tutto lo stile** |
| `app/assets/stylesheets/application.css` | ora è solo il "manifest" che include gli altri CSS |
| `db/seeds.rb` | 4 articoli di esempio |
| `test/controllers/pages_controller_test.rb`, `test/models/article_test.rb` | nuovi test |

Il file `scaffolds.scss` (lo stile grigio dello scaffold) è stato **eliminato**.

## 9.2 La route `root` e il controller delle pagine

```ruby
Rails.application.routes.draw do
  root "pages#home"                               # http://localhost:3000/
  get "chi-sono", to: "pages#about", as: :about   # /chi-sono  → helper about_path

  resources :articles
end
```

- `root "pages#home"` = la pagina `/`. Genera l'helper `root_path`.
- `get "chi-sono", to: "pages#about", as: :about`: URL in italiano, ma il metodo si chiama `about`. `as: :about` dà il nome all'helper (`about_path`). Senza `as:` il nome verrebbe da `chi-sono` e non sarebbe un nome valido.

```ruby
class PagesController < ApplicationController
  def home
    @latest = Article.latest_first.limit(3)    # le ultime 3 per la landing
    @articles_count = Article.count
  end

  def about
  end
end
```

**Per il lavoro**: è il modo standard per pagine che non sono "risorse" (home, about, contatti, privacy). Non serve un modello per avere un controller.

## 9.3 Il layout: la navbar e il footer

[app/views/layouts/application.html.erb](../app/views/layouts/application.html.erb) è il "guscio" in cui Rails infila ogni pagina:

```erb
<body>
  <header class="site-header"> ...navbar... </header>
  <% if notice.present? %> <div class="toast"><%= notice %></div> <% end %>
  <main>
    <%= yield %>        ← qui arriva il contenuto della vista (home, index, show...)
  </main>
  <footer> ... </footer>
</body>
```

Punti chiave:

- **`<%= yield %>`**: il punto in cui il layout inserisce la vista corrente. Navbar e footer stanno nel layout, quindi sono su **tutte** le pagine, scritte una volta sola.
- **Meta viewport** (`<meta name="viewport" ...>`): senza, il sito sul telefono viene mostrato "rimpicciolito" e il responsive non funziona. Mancava nel layout originale.
- **`notice`**: il messaggio flash (es. "Articolo pubblicato!"). Prima ogni vista lo stampava per conto suo con `<p id="notice">`; ora sta nel layout, una volta sola, come notifica che scompare da sola (animazione CSS).
- **Titolo della pagina**: `content_for?(:title)`. Ogni vista può dichiarare il suo titolo:

  ```erb
  <% content_for :title, "Articoli" %>      <%# in index.html.erb %>
  ```
  e il layout lo legge con `yield(:title)` → `<title>Articoli · Fast Break</title>`. `content_for` serve a "mandare" pezzi dalla vista al layout.

### Il link attivo nella navbar

```ruby
# app/helpers/application_helper.rb
def nav_link(text, path, match: nil)
  active = match ? request.path.start_with?(match) : current_page?(path)
  link_to text, path, class: "nav__link#{' is-active' if active}"
end
```

Nella navbar: `<%= nav_link "Articoli", articles_path, match: "/articles" %>`.

- `current_page?(path)`: `true` se stai guardando quella pagina.
- `match: "/articles"`: l'evidenziazione resta anche su `/articles/7` o `/articles/new`.
- Il CSS fa il resto: `.nav__link.is-active` ha la sottolineatura arancione.

Un **helper** è un normale metodo Ruby, disponibile in tutte le viste, per non scrivere logica dentro l'HTML.

### Il menu hamburger su telefono, senza JavaScript

```html
<input type="checkbox" id="nav-toggle" class="nav__toggle">
<label for="nav-toggle" class="nav__burger">...</label>
<div class="nav__menu"> ...link... </div>
```

```css
.nav__toggle:checked ~ .nav__menu { display: flex; }
```

Un checkbox nascosto: cliccare l'icona (il `label`) lo spunta, e il CSS mostra il menu con `:checked`. È un trucco classico che evita JavaScript. Sotto 760px di larghezza il menu si chiude dietro l'icona (`@media (max-width: 760px)`).

## 9.4 Il nome del blog in un solo posto

```ruby
# app/helpers/application_helper.rb
def blog_name    = "Fast Break"
def blog_tagline = "Il basket raccontato da chi lo ama"
```

(Nel codice sono scritti con `def ... end` classico.) Cambia queste due stringhe e il nome si aggiorna in navbar, footer, titolo della pagina e meta tag. **Per il lavoro**: tutto ciò che compare in più punti va messo in un solo posto: è il principio DRY.

## 9.5 I partial: pezzi di vista riusabili

Un file che inizia con `_` è un **partial**. Ce ne sono due nuovi:

**`shared/_ball.html.erb`**, il pallone SVG, con la dimensione come parametro:

```erb
<%= render "shared/ball", size: 34 %>
```
Dentro il partial: `local_assigns.fetch(:size, 40)` = "prendi `size`, se non c'è usa 40".

**`articles/_card.html.erb`**, la scheda di un articolo, usata sia nella home sia nell'elenco:

```erb
<%= render partial: "articles/card", collection: @articles, as: :article %>
```
`collection:` chiama il partial **una volta per ogni articolo** (come un `each`), passandolo come variabile locale `article`. Più pulito del ciclo con l'HTML dentro.

Dentro `_card`, una piccola eleganza: il colore della copertina cambia da un articolo all'altro:

```erb
class="card__cover cover-<%= article.id % 4 %>"
```
`%` è il resto della divisione: l'id dà 0, 1, 2 o 3 → quattro gradienti diversi in CSS (`.cover-0`...`.cover-3`).

## 9.6 La landing page

[app/views/pages/home.html.erb](../app/views/pages/home.html.erb) ha 4 sezioni, dall'alto in basso:

1. **Hero**: sfondo scuro con linee del campo da basket (SVG inline), titolo grande, due pulsanti, tre numeri e il pallone che rimbalza (animazione CSS `@keyframes bounce`).
2. **Il quintetto**: i 5 temi del blog (NBA, Serie A, Tattica, Allenamento, Storia), numerati 1-5 come le posizioni in campo.
3. **Dal parquet**: le ultime 3 card (`@latest`); se non c'è nessun articolo mostra uno stato vuoto con invito a scrivere.
4. **Banda arancione** con invito a scrivere.

Il numero di articoli nel hero viene dal controller (`@articles_count`): è un dato **vero**, non scritto a mano.

> **Come personalizzarla**: i testi stanno tutti in `home.html.erb`. Titolo, sottotitolo, nomi dei 5 temi, descrizioni: sono HTML normale, modificali e salva. Il browser si aggiorna ricaricando la pagina.

## 9.7 Ordinare gli articoli: lo scope `latest_first`

> 🔄 **Aggiornamento (Capitolo 6)**: in questo passo lo scope si chiamava `recent`; il libro usa quel nome per un'altra cosa (gli articoli dell'ultima settimana), quindi è stato rinominato **`latest_first`**. Il codice qui sotto è quello attuale.

```ruby
class Article < ApplicationRecord
  validates :title, :body, presence: true

  scope :latest_first, -> { order(Arel.sql("COALESCE(published_at, created_at) DESC")) }
end
```

- Uno **scope** è una query con un nome, riusabile: `Article.latest_first`, `Article.latest_first.limit(3)`.
- Ordina per `published_at`; se è vuoto (`NULL`) usa `created_at`: lo fa la funzione SQL `COALESCE` ("il primo valore non nullo"). `DESC` = dal più recente.
- `Arel.sql(...)` dice a Rails "questo SQL scritto a mano è sicuro": serve perché Rails, per prudenza, non accetta SQL grezzo dentro `order`.
- Nel controller: `@articles = Article.all` è diventato `Article.latest_first`.

**Per il lavoro**: gli scope sono il modo normale per dare nomi alle query ripetute (`Article.published`, `User.active`). Si possono concatenare: `Article.latest_first.where(location: "Milano").limit(5)`.

## 9.8 Tutto in italiano

Tre tecniche, tutte senza installare niente:

1. **Testi nelle viste**: scritti direttamente in italiano.
2. **Messaggi flash** nel controller: `notice: "Articolo pubblicato!"`.
3. **Messaggi d'errore di validazione** (nel modello e nel locale):

   ```ruby
   validates :title, :body, presence: true       # nel modello: invariato, come nel libro
   ```
   ```yaml
   # config/locales/modelli.yml   (nomi dei campi)
   en:
     activerecord:
       attributes:
         article:
           title: Titolo
           body: Testo
   ```
   ```yaml
   # config/locales/errori.yml    (messaggi predefiniti delle validazioni)
   en:
     errors:
       messages:
         blank: "è obbligatorio"
   ```
   Il nome del campo viene da `human_attribute_name`, che legge `config/locales/`; il testo `blank` è il messaggio predefinito di `presence`. Risultato: **"Titolo è obbligatorio"** invece di "Title can't be blank". (Nel passo 9 il messaggio era scritto nel modello con `message:`; nel Capitolo 6 è stato spostato qui, così vale per tutti i modelli.)

> **Perché il file sta sotto `en:` e non `it:`?** La lingua predefinita dell'app è ancora l'inglese (`:en`). Passare a `:it` richiede le traduzioni di tutto (mesi, errori standard...), tipicamente con la gem `rails-i18n`. In un progetto vero con più lingue si fa così; qui sarebbe eccessivo. È una buona domanda da fare a un collega: "il progetto usa i18n?"

4. **Date**: `datetime_select` mostrava i mesi in inglese. Il form ora usa `form.datetime_local_field :published_at`, il selettore di data/ora **del browser** (nella lingua dell'utente). Un helper scrive le date in italiano:

   ```ruby
   MESI = %w[gennaio febbraio ...]
   def data_it(time) = "#{time.day} #{MESI[time.month - 1]} #{time.year}"   # → "5 ottobre 2026"
   ```

## 9.9 L'articolo: testo e tempo di lettura

In `show.html.erb`:

```erb
<%= simple_format(@article.body) %>
```

`simple_format` trasforma il testo semplice in HTML: una riga vuota → nuovo paragrafo `<p>`, a capo singolo → `<br>`. Fa anche `sanitize`: i tag pericolosi (`<script>`) vengono tolti. Scrivere un articolo = scrivere testo normale nel textarea.

Tempo di lettura (in `ArticlesHelper`):

```ruby
def reading_time(article)
  minutes = [(article.body.to_s.split.size / 200.0).ceil, 1].max
  "#{minutes} min di lettura"
end
```
Conta le parole, dividi per 200 (parole al minuto), arrotonda per eccesso (`ceil`), minimo 1. Nota `200.0`: con `200` la divisione tra interi darebbe un intero (vedi Capitolo 4, "Numeri").

## 9.10 I dati di esempio: `db/seeds.rb`

```bash
bin/rails db:seed
```

```ruby
Article.find_or_create_by!(title: attrs[:title]) do |article|
  article.assign_attributes(attrs)
end
```

- Il file `db/seeds.rb` è un normale script Ruby con l'app caricata: serve a riempire il DB con dati iniziali.
- `find_or_create_by!`: se esiste già un articolo con quel titolo lo lascia, altrimenti lo crea. Quindi **puoi rilanciare `db:seed` senza duplicare**.
- I 4 articoli sono **testi di prova**: riscrivili a modo tuo o cancellali da `/articles` (Elimina).
- Gli articoli multi-riga usano `<<~TEXT ... TEXT`, un *heredoc*: stringa su più righe con indentazione ignorata.

**Per il lavoro**: `db:seed` si usa per dati che servono sempre (ruoli, categorie, un utente admin di sviluppo). Il comando `bin/rails db:setup` (crea DB + schema + seed) è quello che si dà a un collega appena clonato il progetto.

## 9.11 Il CSS

Tutto in [app/assets/stylesheets/blog.css](../app/assets/stylesheets/blog.css). Come è organizzato:

- **Variabili CSS** all'inizio (`:root { --orange: #f2631a; ... }`): i colori e i font. Per cambiare tema (es. i colori della tua squadra) modifica **solo quelle righe**. Prova: cambia `--orange` con il colore della tua squadra.
- **Font**: *Bebas Neue* (titoli) e *Inter* (testo), caricati da Google Fonts nel layout. Senza internet funziona lo stesso con i font di riserva (`Impact`, `system-ui`).
- **Sezioni commentate**: bottoni, navbar, hero, card, form, footer...
- **Responsive**: `@media (max-width: ...)` adatta layout a tablet e telefono (griglie da 3 → 2 → 1 colonna, navbar a hamburger).
- **Accessibilità**: `prefers-reduced-motion` spegne le animazioni a chi le ha disattivate nel sistema; `:focus-visible` mostra un contorno arancione quando navighi da tastiera.

### Come funziona la pipeline degli asset

`application.css` è un **manifest**:

```css
/*
 *= require_tree .     ← include tutti i CSS di questa cartella
 *= require_self
 */
```

Per aggiungere un nuovo CSS basta creare un file nella cartella: viene incluso da solo. In sviluppo Rails ricompila a ogni richiesta.

### ⚠️ Un problema incontrato: `min()` e Sass

Il primo CSS usava `width: min(1120px, 100% - 40px)`. Il compilatore Sass di Rails 6 lo ha rifiutato (`Incompatible units: 'px' and '%'`), perché tenta di calcolare `min()` da solo e non può mischiare `px` e `%`. La soluzione equivalente:

```css
.container { width: calc(100% - 40px); max-width: 1120px; }
```

**Lezione**: gli errori dei CSS in Rails compaiono come errore **nella pagina** (`ActionView::Template::Error`), perché il foglio di stile viene compilato quando il layout lo richiede. Il test li ha scoperti subito (7 errori in `bin/rails test`). Un buon motivo per avere test, anche semplici.

## 9.12 I test aggiunti

```ruby
# test/controllers/pages_controller_test.rb
test "la landing page risponde e ha la navbar" do
  get root_url
  assert_response :success
  assert_select "nav.nav a.nav__link", minimum: 3
  assert_select "h1.hero__title"
end
```

- `get root_url`: simula una richiesta a `/`.
- `assert_response :success`: la risposta deve essere 200.
- `assert_select`: controlla che nell'HTML ci sia quell'elemento (selettore CSS).

```ruby
# test/models/article_test.rb
test "titolo e testo sono obbligatori" do
  article = Article.new
  assert_not article.valid?
  assert_includes article.errors.full_messages, "Titolo è obbligatorio"
end
```

Output: **13 test, 0 errori**. Rilancia con `bin/rails test`.

---

## 9.13 Provarlo

```bash
cd /home/wonderlab/blog
bin/rails db:seed      # se non l'hai ancora fatto
bin/rails server
```

| URL | Pagina |
|---|---|
| <http://localhost:3000/> | landing page |
| <http://localhost:3000/articles> | elenco articoli |
| <http://localhost:3000/articles/new> | scrivi un articolo |
| <http://localhost:3000/chi-sono> | chi sono |

Prova anche a restringere la finestra del browser: la navbar diventa hamburger.

## 9.14 Cose da personalizzare (compiti per te)

1. **Nome e slogan**: `ApplicationHelper#blog_name` e `#blog_tagline`.
2. **Colori**: le variabili `--orange` e `--ink` in `blog.css` (prova i colori della tua squadra).
3. **Chi sono**: riscrivi `about.html.erb` con la tua storia, squadra e giocatore preferito (ci sono due "Da aggiungere" nella scheda giocatore).
4. **Quintetto**: cambia i 5 temi in `home.html.erb` con quelli che vuoi davvero trattare.
5. **Articoli**: sostituisci i 4 di esempio con i tuoi.
6. **Esercizio**: aggiungi un campo `category` (migrazione + `permit` + form + card) per mostrare l'etichetta "NBA", "Tattica"... su ogni card. È il passo 5 della guida, applicato a un caso reale.

## ⚠️ Cosa NON c'è ancora (importante per il lavoro)

**Chiunque può creare, modificare ed eliminare articoli**: non c'è nessun login. Va bene in locale, **non su un sito pubblico**. Il passo successivo, prima di mettere il blog online, è l'autenticazione (la gem `devise`, o `has_secure_password` incluso in Rails), con i pulsanti Scrivi/Modifica/Elimina visibili solo a te. Altre cose mancanti: commenti (relazioni `has_many`), immagini (Active Storage), paginazione. Sono buoni prossimi esercizi.

---

## 🧠 Domande di verifica

1. Dove metteresti il numero di telefono, mostrato in navbar e footer? Perché lì?
2. Cosa fa `<%= yield %>` nel layout? E `content_for :title`?
3. Che differenza c'è tra una vista e un partial? Come si chiama un partial per ogni elemento di una lista?
4. A cosa serve uno `scope`? Come sarebbe uno scope `published` per gli articoli con `published_at` valorizzato?
5. Perché rilanciare `db:seed` non duplica gli articoli?
6. Il CSS dà un errore Sass dentro la pagina: dove guardi per primo?

<details><summary>Risposte</summary>

1. In un helper (es. `ApplicationHelper#contact_phone`), chiamato da navbar e footer: DRY, si cambia in un punto solo.
2. `yield` è il punto del layout dove entra la vista corrente; `content_for :title` manda un pezzo (il titolo) dalla vista al layout.
3. Un partial (file con `_`) è un pezzo riusabile incluso con `render`. Per ogni elemento: `render partial: "articles/card", collection: @articles, as: :article`.
4. Una query con un nome, riusabile e concatenabile. Es. `scope :published, -> { where.not(published_at: nil) }`.
5. Usa `find_or_create_by!(title: ...)`: se il titolo esiste già lo trova e non crea niente.
6. Nel messaggio d'errore nel browser (indica riga e file), e nel terminale del server / `log/development.log`.

</details>
