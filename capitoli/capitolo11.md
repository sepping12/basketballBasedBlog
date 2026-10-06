# Capitolo 11 — Action Text

> **In una frase**: Action Text dà al testo degli articoli un **editor visuale** (Trix: grassetto, elenchi, link, citazioni, immagini) e lo salva come **HTML in una tabella a parte**, ripulendolo quando lo mostra. Basta `has_rich_text :body` nel modello e `rich_text_area` nel form.

## 1. Il contesto (la mappa mentale)

Finora il testo era una stringa semplice in una colonna. Ora è HTML modificabile da chi non conosce l'HTML:

```
 BROWSER                                                 SERVER
 ┌───────────────────────────────┐  invio   ┌──────────────────────────────────────────┐
 │ <trix-editor>   (JavaScript)  │ ───────► │ params[:article][:body] = "<div>Un <strong>…" │
 │  [B] [I] [link] [elenco] [📎] │          │        │                                 │
 │  ┌─────────────────────────┐  │          │        ▼                                 │
 │  │ testo formattato        │  │          │ Article#body = ActionText::RichText      │
 │  └─────────────────────────┘  │          │        │ salvato in action_text_rich_texts│
 │ <input type="hidden"          │          │        ▼                                 │
 │  name="article[body]"> (HTML) │ ◄─────── │ in visualizzazione: ripulito (sanificato)│
 └───────────────────────────────┘ pagina   └──────────────────────────────────────────┘
```

Tre pezzi, come per Active Storage:

| Pezzo | Dove | Cosa fa |
|---|---|---|
| **Trix** | JavaScript nel browser | l'editor: costruisce la barra degli strumenti e scrive l'HTML in un campo **nascosto** |
| **Tabella `action_text_rich_texts`** | database | polimorfica: `name` ("body"), `body` (l'HTML), `record_type`, `record_id`. Un indice **univoco** su `(record_type, record_id, name)` |
| **`has_rich_text :body`** | modello | collega l'attributo a quella tabella |

## 2. Cosa ho fatto

| Passo | Comando / file |
|---|---|
| Installazione | `bin/rails action_text:install` → CSS, JavaScript, template per gli allegati, fixture, migrazione |
| Versioni JavaScript | fissate **tutte** alla 6.0.6-1 in `package.json` (vedi sotto) |
| Tabella | `bin/rails db:migrate` → `action_text_rich_texts` |
| Modello | `has_rich_text :body` in `Article` |
| Dati esistenti | migrazione `MigrateArticleBodyToActionText` (copia i 4 testi) + `RemoveBodyFromArticles` (toglie la colonna) |
| Form | `form.rich_text_area :body` al posto della textarea |
| Viste | `show` stampa `@article.body`; scheda e tempo di lettura usano `to_plain_text` |
| N+1 | `with_rich_text_body` negli elenchi |
| Stile | `.trix-content` dentro `.prose`, aspetto di `trix-editor`, capolettera solo sui paragrafi |
| Italiano | tooltip di Trix in italiano (`app/javascript/trix_italiano.js`) |
| API JSON | `body` (testo semplice) e `body_html` (HTML sanificato) |
| Test | **148** (19 nuovi) |
| Prove | [capitolo11_esercizi.rb](capitolo11_esercizi.rb) |

### Dove ho deviato dal libro (e perché)

| Cosa | Libro | Qui | Motivo |
|---|---|---|---|
| Migrazione dei dati | un `INSERT … SELECT` che copia il testo **così com'è** | **in Ruby**: converte i paragrafi in `<p>…</p>` e neutralizza l'HTML | il vecchio testo era *semplice* (paragrafi separati da una riga vuota). Copiato tale e quale, i paragrafi si fonderebbero in uno solo, e un `<b>` scritto per caso diventerebbe grassetto |
| Togliere la colonna | `remove_column` | con una **rete di sicurezza**: si ferma se un testo non è stato copiato | la perdita di dati sarebbe irreversibile |
| Rollback | ricrea la colonna **vuota** | la ricrea **e rimette il testo** (in testo semplice) | provato su una copia del database |
| JavaScript | `yarn add` (versioni "alte") | **tutte le librerie `@rails/*` alla 6.0.6-1** | `yarn` aveva preso la 6.1.710 (compatibile solo "in apparenza") con le gemme 6.0.6 |
| Elenco articoli | `.includes(:user).with_rich_text_body.with_attached_cover_image` | `.includes(:categories).with_rich_text_body.with_attached_cover_image` | il blog non mostra l'utente nell'elenco, ma mostra le categorie |
| `simple_format article.body` → `article.body` | come il libro | come il libro, **più** `to_plain_text` dove serve testo semplice | scheda, tempo di lettura, JSON |
| Toolbar | inglese | italiano | coerenza col sito |

## 3. I concetti chiave

### 3.1 Cosa cambia con `has_rich_text :body`

```ruby
has_rich_text :body
```

| Prima | Dopo |
|---|---|
| `article.body` → una **stringa** (colonna di `articles`) | `article.body` → un oggetto **`ActionText::RichText`**, che contiene un `ActionText::Content` |
| `Article.column_names` ha `body` | **non** ha più `body`; il testo sta in un'altra tabella |
| `article.body = "testo"` | assegna l'**HTML** all'oggetto collegato |
| — | nuovo scope `Article.with_rich_text_body` |

Come leggerlo (tutto verificato):

| Chiamata | Risultato |
|---|---|
| `article.body.to_s` | HTML **sanificato**, avvolto in `<div class="trix-content">…</div>` (è ciò che stampa `<%= article.body %>`) |
| `article.body.to_plain_text` | solo il testo: `"Titolo\n\nUn grassetto e un corsivo\n• uno\n• due"` |
| `article.body.body.to_html` | l'HTML **grezzo** com'è nel database |
| `article.body.body.to_trix_html` | l'HTML con la sintassi che capisce l'editor |
| `article.body.blank?` | `true` se è vuoto (anche `<div><br></div>`, un editor "vuoto") |
| `article.body.embeds` | i file incorporati nel testo |

**La validazione `validates :body, presence: true` continua a funzionare**: un testo vuoto dà "Testo è obbligatorio".

### 3.2 Cosa fa l'installazione

| Cosa | Dove | Come viene incluso |
|---|---|---|
| CSS di Action Text/Trix | `app/assets/stylesheets/actiontext.scss` | **da solo**: `application.css` ha `require_tree .` (convenzione sopra configurazione). Il file stesso carica `trix/dist/trix` da `node_modules` |
| JavaScript | `trix` e `@rails/actiontext` in `package.json`, versioni esatte in `yarn.lock` | due `require` in `app/javascript/packs/application.js` |
| Tabella | migrazione `create_action_text_tables` | `db:migrate` |
| Template per le immagini | `app/views/active_storage/blobs/_blob.html.erb` | usato per mostrare un'immagine incorporata |
| Fixture di esempio | `test/fixtures/action_text/rich_texts.yml` | per i test |

Conseguenza pratica: il pacchetto JavaScript di sviluppo è passato da 123 KB a circa **500 KB** (Trix pesa).

### 3.3 Il form

```erb
<%= form.rich_text_area :body %>
```

Genera due cose (verificato nell'HTML):
- `<trix-editor … input="article_body_trix_input_article_9" data-direct-upload-url="…">`: l'editor; **la barra degli strumenti la crea il JavaScript nel browser**, non c'è nell'HTML del server;
- `<input type="hidden" name="article[body]" value="<p>…</p>">`: il campo che **invia l'HTML**. Per questo nel controller basta lasciare `:body` tra i `permit`.

Niente più `<textarea>`. **Compromesso**: senza JavaScript non si può modificare il testo (il campo nascosto non è editabile).

### 3.4 L'HTML si ripulisce quando si mostra, non quando si salva

Cosa succede con un testo "sporco" (verificato):

```html
<div onclick="rubaDati()">Ciao</div><script>alert('xss')</script><a href="javascript:alert(1)">clic</a>
<a href="https://esempio.it" target="_blank">link vero</a><strong>ok</strong><iframe src="https://x"></iframe>
```

| Dove | Cosa c'è |
|---|---|
| **Nel database** | tutto, **com'è stato inviato** |
| **In `to_s` / nella pagina** | `<div>Ciao</div>alert('xss')<a>clic</a><a href="https://esempio.it">link vero</a><strong>ok</strong>` |

Spariscono `onclick`, i tag `<script>` e `<iframe>`, l'attributo `target` e il link `javascript:`. Restano i tag innocui (`<strong>`, `<a href="https://…">`…) in una **lista di permessi** (`ActionText::ContentHelper.allowed_tags`: `a`, `b`, `blockquote`, `br`, `code`… e `action-text-attachment`).

⚠️ Il testo di una `<script>` resta come testo semplice (qui "alert('xss')"): è solo testo, non codice. E poiché il database contiene l'HTML grezzo, **non va mai stampato con `raw` o `html_safe`**: si stampa sempre con `<%= article.body %>`, che sanifica.

### 3.5 Immagini dentro il testo

La graffetta di Trix carica un file con **Active Storage** (upload diretto, senza passare dal form). Nel testo compare un tag firmato:

```html
<action-text-attachment sgid="BAh7CEkiCGdpZ…"></action-text-attachment>
```

Verificato: `article.body.embeds` elenca i file; `to_plain_text` li mostra come `[copertina.png]`; l'allegato appartiene al **`RichText`** (non all'articolo): `record_type = "ActionText::RichText"`; in visualizzazione diventa un `<figure>` con un'immagine (template `_blob.html.erb`, con una **variante** ridimensionata: serve ImageMagick, Capitolo 10).

### 3.6 Spostare i dati esistenti

```
articles.body (testo semplice)  ──migrazione 1──►  action_text_rich_texts (HTML)  ──migrazione 2──►  colonna eliminata
   "Primo.\n\nSecondo\nsu due"                       "<p>Primo.</p><p>Secondo<br>su due</p>"
```

Verificato su una **copia** del database: il rollback ricrea `articles.body` con i testi, e rieseguire le migrazioni li riporta in Action Text (4 testi, colonna tolta). Il mio database non è stato toccato dalla prova.

### 3.7 Cercare nel testo

`Article.where("body LIKE …")` **non funziona più** (`no such column: body`). Serve un join:

```ruby
Article.joins(:rich_text_body).where("action_text_rich_texts.body LIKE ?", "%pick and roll%")
```

Si cerca nell'**HTML** (quindi anche nei nomi dei tag). Per ricerche serie: ricerca full-text (PostgreSQL) o una colonna col testo semplice.

### 3.7bis `delete` lascia il testo orfano

`article.destroy` elimina anche il suo testo (0 righe rimaste); **`Article.delete(id)` no** (1 riga orfana), perché salta i callback. Peggio: se poi un nuovo articolo prende lo stesso `id`, l'indice univoco dà `UNIQUE constraint failed`. Con Action Text (e con Active Storage) si usa **`destroy`**.

### 3.8 Query N+1

Con 10 articoli (verificato):

| Query | Numero |
|---|---:|
| `Article.all.each { \|a\| a.body.to_plain_text }` | **11** (una per articolo) |
| `Article.with_rich_text_body.each { … }` | **2** |
| `.with_rich_text_body.with_attached_cover_image.includes(:categories)` e si usano tutti | **6** |

Il test `ArticlesRichTextControllerTest` verifica che l'elenco faccia **lo stesso numero di query con 2 o con 12 articoli**.

## 4. Trappole e scoperte

| Cosa | Spiegazione |
|---|---|
| `yarn add` e le versioni | `@rails/actiontext@^6.0.6-1` ha preso la **6.1.710**: con `^` yarn sale di versione minore. Fissato a `6.0.6-1` (e così `ujs`, `activestorage`, `actioncable`) |
| `to_s` in una vista JSON | cerca un template HTML con il formato della richiesta (JSON) e non lo trova: `Missing partial action_text/content/_layout`. Soluzione: `ActionText::Content.with_renderer(ApplicationController.renderer) { article.body.to_s }` |
| `read_attribute(:body)` | restituisce già un `ActionText::Content`, non la stringa del database: per il valore grezzo, SQL o `body.body.to_html` |
| `trix-toolbar` nei test | non c'è nell'HTML del server (lo crea il JavaScript): il test controlla `trix-editor` e il campo nascosto |
| `fixtures` | `body:` non è più una colonna: i testi stanno in `test/fixtures/action_text/rich_texts.yml` con `record: one (Article)` (in Rails 6.0 si scrive così) |
| Capolettera | andava sul titolo `<h1>` quando era il primo elemento: ora solo su paragrafi |
| Script dei capitoli 5 e 6 | usavano `body` in SQL e `delete_all`: aggiornati (`excerpt`, `destroy_all`). Il capitolo 5 era rimasto indietro dal Capitolo 8 (articoli senza autore) |
| `rails db:rollback` e `db/schema.rb` | anche sulla copia riscriverebbe `db/schema.rb`, e Rails ricarica le classi: ho usato `SCHEMA=file_temporaneo` |
| Script interrotti | due esecuzioni interrotte avevano lasciato 2 file orfani (`Blob.unattached`): ripuliti |

## 5. Come provarlo

```bash
bin/rails server          # accedi, "Scrivi" (o modifica un articolo): editor Trix con i testi in italiano
bin/rails test            # 148 test
PATH="$HOME/.local/bin:$PATH" bin/rails runner capitoli/capitolo11_esercizi.rb
```

Prova: scrivi un articolo con un titolo, un elenco e un link; incolla un testo con un `<script>` (usa "Codice" o incolla da una pagina) e guarda che sulla pagina non venga eseguito.

## 6. Checklist del capitolo

- [x] `rails action_text:install` e cosa fa (CSS, JavaScript, tabella)
- [x] `has_rich_text :body`
- [x] Migrazione dei dati e rimozione della colonna (reversibile)
- [x] `rich_text_area` nel form (Trix)
- [x] `article.body` nella vista (sanificato)
- [x] `with_rich_text_body` contro le query N+1
- [x] Sanificazione (XSS) verificata
- [x] Immagini incorporate (Action Text + Active Storage)
- [x] 148 test; verifica nel browser (editor e pagina)

## 7. Auto-verifica

1. Dove sta il testo di un articolo ora, e cosa restituisce `article.body`?
2. Perché la migrazione dei dati converte i paragrafi in `<p>` invece di copiare il testo com'è?
3. L'HTML con `<script>` viene salvato così com'è o ripulito? E quando?
4. Perché `Article.delete(id)` è pericoloso con Action Text?
5. Come si cerca una parola nel testo di un articolo?
6. Perché la barra degli strumenti di Trix non compare nei test del controller?
7. Cosa fa `with_rich_text_body`?

<details><summary>Risposte</summary>

1. Nella tabella `action_text_rich_texts` (polimorfica). `article.body` è un `ActionText::RichText`, non una stringa; `to_s` dà l'HTML sanificato, `to_plain_text` il solo testo.
2. Il vecchio testo era semplice: copiato com'è, i paragrafi (righe vuote) si fonderebbero in uno solo in HTML, e un eventuale `<b>` diventerebbe grassetto.
3. Salvato **com'è**; ripulito **quando viene mostrato** (`<%= article.body %>`).
4. Salta i callback: il testo (e gli allegati) restano orfani nelle tabelle collegate, e un nuovo articolo con lo stesso id va in conflitto sull'indice univoco. Si usa `destroy`.
5. Con un join: `Article.joins(:rich_text_body).where("action_text_rich_texts.body LIKE ?", "%parola%")`; cerca nell'HTML.
6. La crea il JavaScript nel browser; il test vede solo l'HTML del server (`<trix-editor>` e il campo nascosto).
7. Carica in anticipo i testi di tutti gli articoli con una sola query, invece di una per articolo (N+1).

</details>

---

**Prossimo capitolo**: il **12** tratta **l'invio e la ricezione di email** (Action Mailer): il blog avviserà l'autore di un articolo quando riceve un commento — è il "We will notify … in Chapter 12" che il callback stampa dal Capitolo 6.
