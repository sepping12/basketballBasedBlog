# Capitolo 9 — JavaScript e CSS

> **In una frase**: Rails ha due sistemi per gli asset (uno per CSS e immagini, uno per JavaScript), una libreria che rende la navigazione più veloce (Turbolinks), e un modo semplice di fare **Ajax**: aggiornare parti della pagina senza ricaricarla. Qui il form dei commenti diventa "a richiesta" e i commenti si inviano e si eliminano senza cambiare pagina.

## 1. Il contesto (la mappa mentale)

### I due sistemi per gli asset

| | **Asset Pipeline** (Sprockets) | **webpack** (gemma Webpacker) |
|---|---|---|
| Per cosa | CSS (anche **SASS**), immagini, font | **JavaScript** (anche ES6+, convertito per i browser vecchi) |
| Sorgenti in | `app/assets/` (anche `lib/assets`, `vendor/assets`) | `app/javascript/` |
| Punto di ingresso | `application.css` (un **manifest**: `require_tree .`) | `app/javascript/packs/application.js` (un **pack**) |
| Risultato | servito da `/assets/…` | scritto in `public/packs/` |
| Nel blog | `blog.css` (il tema) | `require("@rails/ujs")`, `require("turbolinks")`, … |

**Perché preprocessare?** Tre benefici: **concatenare** (meno file da scaricare), **minificare/comprimere** (file più piccoli), **usare linguaggi migliori** (SASS al posto di CSS, ES6 al posto di JS vecchio) che vengono tradotti per il browser.

### Il flusso di una richiesta Ajax (quello che costruiamo)

```
1. Clic su  "Scrivi un commento"   (link con remote: true)
2. rails-ujs (JavaScript già nella pagina) invia una richiesta XHR:  GET /articles/5/comments/new
                                                  header:  Accept: text/javascript,  X-Requested-With: XMLHttpRequest
3. Il controller risponde con un template .js.erb → NON HTML, ma codice JavaScript
4. rails-ujs VALUTA quel codice nel browser  →  modifica il DOM (la pagina cambia senza ricaricarla)
```

Il codice JavaScript arriva dal **server**, e il browser lo esegue: è il modello "server-generated JavaScript" tipico di Rails 6 (con Rails 7 si passa a Hotwire/Turbo, che ha un'idea simile ma con HTML).

## 2. Cosa ho fatto

La parte teorica (asset, webpack, Turbolinks) l'ho **verificata con esperimenti veri**; la parte pratica (Ajax sui commenti) l'ho **implementata nel blog**.

| Cosa | Dove |
|---|---|
| Il form si carica a richiesta (link Ajax) | `comments/new.js.erb`, `show.html.erb` |
| Invio del commento senza ricaricare | `comments/create.js.erb`, `fail_create.js.erb`, form remoto |
| Eliminazione senza ricaricare | `comments/destroy.js.erb`, link `remote: true` |
| Messaggio temporaneo (al posto del flash) | `shared/_toast.js.erb` |
| Entrata in dissolvenza | classe CSS `.fade-in` in `blog.css` |
| Versione senza JavaScript (fallback) | `comments/new.html.erb` |
| Route e controller | `resources :comments, only: [:new, :create, :destroy]`; `respond_to` in `CommentsController` |
| Test | **102** (10 nuovi, sui flussi Ajax) |
| Prove lato Rails | [capitolo9_esercizi.rb](capitolo9_esercizi.rb) → `bin/rails runner capitoli/capitolo9_esercizi.rb` |
| Prova **nel browser** (DOM simulato) | [capitolo9_prova_ajax.js](capitolo9_prova_ajax.js) → **36 controlli**, tutti riusciti |

### Dove ho deviato dal libro (e perché)

| Cosa | Libro | Qui | Motivo |
|---|---|---|---|
| Errore di validazione (Ajax) | `alert("…")` con i messaggi | il **form si ri-mostra con gli errori** e il testo già scritto | niente finestre di dialogo; e il libro mette `.html_safe` dentro l'`alert` (rischio XSS) |
| Dove va il form | `insertAdjacentHTML("afterend", …)` accanto alla lista | in un contenitore dedicato `#form-commento` | si può svuotare e sostituire con un form pulito |
| Fade-in | JavaScript (`opacity` + `setTimeout`) | una **regola CSS** (`@keyframes`) | il libro stesso dice che "ci sarebbero modi migliori" |
| `removeChild` | per i browser vecchi | `.remove()` | oggi tutti i browser lo supportano |
| Dopo il commento | il form resta com'è (`reset()`) | si sostituisce con uno **nuovo e vuoto**, e si aggiorna il titolo "N commenti" | non restano errori vecchi nel form |
| Messaggio di conferma | nessuno | un avviso temporaneo (`.toast`) | in Ajax non c'è un redirect, quindi non c'è un flash |
| Senza JavaScript | `new` non ha una vista HTML (dà errore) | `new.html.erb`: una pagina con il form | il sito resta usabile anche se il JavaScript non parte |
| Form dei commenti nella pagina | sempre visibile (cap. 8) | a richiesta, via Ajax | è proprio l'esercizio del capitolo |

## 3. I concetti chiave

### 3.1 I benefici del preprocessamento, con numeri veri

Ho lanciato la precompilazione di produzione (`RAILS_ENV=production bin/rails assets:precompile`, 21 secondi) e misurato:

| | Sviluppo | Produzione (minificato) | Con gzip |
|---|---:|---:|---:|
| **CSS** (`application.css`) | 21.364 byte, 415 righe | 17.565 byte, **1 riga** | **4.498 byte** (−79%) |
| **JavaScript** (il pack) | 123.586 byte | 70.062 byte | **17.979 byte** (−85%); brotli 15.580 |

**Impronta digitale nel nome**: `application-22676b96…c3c585eafa.css`, `application-b35720b1…js`. Se il contenuto cambia, cambia il nome: il browser può tenere il file in cache **per sempre**, e scarica quello nuovo solo quando serve.

Il pack (70 KB) è molto più grande del tuo `application.js` (746 byte): contiene le **librerie** che questo importa (`rails-ujs`, `turbolinks`, `activestorage`, `actioncable`).

Una curiosità trovata: in produzione compaiono due file CSS identici (`application-…css` e `blog-…css`), perché il manifest di Rails (`link_directory ../stylesheets`) pubblica anche ogni singolo file. È innocuo, ma inutile.

### 3.2 Dove mettere i file

| Dove | Gestito da | Per |
|---|---|---|
| `app/assets/` | Asset Pipeline | asset della tua app (CSS, immagini) |
| `lib/assets/` | Asset Pipeline | asset tuoi, condivisi tra più app |
| `vendor/assets/` | Asset Pipeline | asset di terzi |
| `app/javascript/packs/` | webpack | i *pack* (punti di ingresso JS) |
| `app/javascript/` | webpack | file JS più piccoli, importati dai pack |

### 3.3 Turbolinks

Trasforma ogni clic su un link in una richiesta Ajax e **sostituisce solo il `<body>`**, senza ricaricare CSS e JavaScript: la navigazione è più veloce. Gestisce anche URL e pulsanti avanti/indietro.

- Si disattiva su un singolo link con `data: { turbolinks: false }` → `<a data-turbolinks="false" …>` (verificato).
- `data-turbolinks-track="reload"` nel layout: se cambia l'impronta del file, fa un ricaricamento completo (per prendere il codice nuovo).
- **Effetto collaterale utile da sapere**: se una richiesta Ajax finisce con un redirect (es. non sei loggato), la gemma Turbolinks lo trasforma in JavaScript: `Turbolinks.visit("http://…/login")` con status **200**. Verificato.

### 3.4 Il DOM e i selettori

Il **DOM** è la rappresentazione della pagina, che JavaScript può modificare. I metodi usati nei template del blog:

| Codice | Fa |
|---|---|
| `document.querySelector("#commenti-lista")` | **un** elemento (il primo che corrisponde a un selettore CSS) |
| `document.querySelectorAll(".comment")` | **tutti** gli elementi (una lista) |
| `elemento.insertAdjacentHTML("beforeend", html)` | inserisce HTML: `beforebegin`, `afterbegin`, `beforeend`, `afterend` |
| `elemento.classList.add("fade-in")` | aggiunge una classe CSS |
| `elemento.style.display = "none"` | nasconde |
| `elemento.remove()` | toglie dalla pagina |
| `elemento.textContent = "3 commenti"` | cambia il testo (**mai** interpretato come HTML: sicuro) |

Con jQuery un tempo si scriveva `$("#x")`: oggi i browser hanno API coerenti e non serve più.

### 3.5 Ajax in Rails, in 4 mosse

| Mossa | Come |
|---|---|
| **1. Link Ajax** | `link_to "…", path, remote: true` → l'attributo `data-remote="true"` fa partire una richiesta XHR |
| **2. Form Ajax** | `form_with` è **remoto di default** in Rails 6.0 (verificato); `local: true` lo rende normale |
| **3. Il controller risponde in base al formato** | `respond_to do \|format\| format.html {…}; format.js end` |
| **4. Template `.js.erb`** | un blocco `format.js` **vuoto** → Rails cerca `nome_azione.js.erb` |

```ruby
respond_to do |format|
  if @comment.save
    format.html { redirect_to article_path(@article, anchor: "commenti"), notice: "…" }
    format.js                                          # → create.js.erb
  else
    format.html { render "articles/show", status: :unprocessable_entity }
    format.js   { render :fail_create, status: :unprocessable_entity }
  end
end
```

**Il template JavaScript** è un normale ERB: ciò che stampa è codice JavaScript.

```erb
document.querySelector("#commenti-lista").insertAdjacentHTML("beforeend", "<%= j render(@comment) %>");
```

**`j` = `escape_javascript`**. Serve per mettere l'HTML dentro una stringa JavaScript. Cosa fa **davvero** (verificato):

| Carattere | Diventa |
|---|---|
| `"` e `'` | `\"` e `\'` |
| a capo | `\n` |
| `</` | `<\/` (così un `</script>` nel testo non può chiudere lo script) |
| `<` da solo | **resta** `<` |

I test lo verificano con un commento pieno di virgolette e di `</script>`: il JavaScript non si rompe.

### 3.6 Sicurezza di Ajax

| Cosa | Come funziona |
|---|---|
| **CSRF** | `rails-ujs` legge il token dal tag `<meta name="csrf-token">` (`csrf_meta_tags` nel layout) e lo invia in ogni richiesta Ajax |
| **JavaScript "da altri siti"** | una GET che risponde JavaScript è accettata **solo se è una richiesta Ajax** (`X-Requested-With`): altrimenti un sito esterno potrebbe includerla con un tag `<script src=…>` e leggere i tuoi dati. Verificato: senza `xhr: true` → 422 (in sviluppo), `InvalidCrossOriginRequest` (nei test) |
| **XSS nelle risposte JS** | il nome del commentatore `<b>Tester</b>` finisce nella pagina come **testo**; il `</script>` scritto nel testo viene eliminato da `simple_format`. Verificato nel DOM simulato |
| **Autorizzazione** | invariata: `destroy` richiede login e proprietà dell'articolo, anche via Ajax |
| **Il libro: `alert("<%= … .html_safe %>")`** | con `html_safe` il testo non viene escapato: se un messaggio contenesse input dell'utente si potrebbe rompere la stringa. Meglio evitarlo (qui: niente `alert`) |

### 3.7 Miglioramento progressivo

Il sito deve funzionare **anche senza JavaScript** (o se il JavaScript non parte). Per questo:
- il link "Scrivi un commento" ha un `href` vero: senza JS porta a `comments/new.html.erb`, una pagina con il form (invio normale);
- i `format.html` restano (redirect o ri-mostra la pagina con gli errori).

Il JavaScript è un **miglioramento**, non un requisito.

### 3.8 Stato HTTP e Ajax

- rails-ujs **valuta la risposta JavaScript anche con status 4xx** (l'ho verificato nel suo codice: `processResponse` viene chiamata prima del controllo dello status). Per questo `fail_create` può rispondere **422** (semanticamente corretto) e il form con gli errori compare comunque.
- Dopo un'azione Ajax **non** c'è un redirect: la pagina resta, e quindi il `flash` non servirebbe. Ecco il perché dell'avviso temporaneo creato via JavaScript.

## 4. Trappole e scoperte

| Cosa | Spiegazione |
|---|---|
| `new` per Ajax e per HTML | con la route `only: [:create, :destroy]` il link Ajax avrebbe dato 404: ora serve anche `:new` (nel libro le route erano tutte) |
| Redirect in una risposta Ajax | diventa JavaScript `Turbolinks.visit(…)` con status 200 (il mio primo test si aspettava un 302) |
| `escape_javascript` non escapa `<` | solo virgolette, a capo e `</` (il mio primo test si aspettava `<`) |
| `@article.comments.new` per il form | aggiunge un commento non salvato alla lista: nel form uso `Comment.new` |
| ID nel DOM | i template JS trovano gli elementi per `id` (`#commenti-lista`, `#commenti-vuoto`, `#commenti-titolo`, `#form-commento`, `#commento-ID`): se cambi un id nella vista, il JavaScript smette di funzionare **in silenzio** |
| Errori JS | se un elemento non esiste, `querySelector` restituisce `null` e il codice solleva un errore nella console del browser |
| Dopo `assets:precompile` | crea `public/assets` e `public/packs` in produzione: li ho eliminati e ricompilato il pack di sviluppo (con `NODE_ENV=development`: il comando di compilazione usa la produzione di default) |
| I test non vedono il JavaScript | verificano che Rails **risponda** il codice giusto; per vedere che la pagina **cambi** serve un browser (qui: DOM simulato con jsdom) |

## 5. Come provarlo

```bash
bin/rails server                      # apri un articolo: il form non c'è, clicca "Scrivi un commento"
bin/rails test                        # 102 test
bin/rails runner capitoli/capitolo9_esercizi.rb
```

Prova nel DOM simulato (jsdom non è una dipendenza del progetto, si installa a parte; le istruzioni sono in cima al file):

```bash
mkdir /tmp/jsd && cd /tmp/jsd && npm install jsdom@22
# con il server acceso, per un articolo pubblicato di mary@example.com:
NODE_PATH=/tmp/jsd/node_modules node <progetto>/capitoli/capitolo9_prova_ajax.js 5
```

Cosa controlla (36 verifiche): il form non è nella pagina → compare dopo il clic (con focus e animazione) → un commento non valido mostra gli errori senza perdere il testo → uno valido si aggiunge, il titolo diventa "N commenti" e il form si svuota → l'autore elimina il commento e la pagina si aggiorna.

## 6. Checklist del capitolo

- [x] Benefici del preprocessamento: concatenazione, compressione, linguaggi secondari (misurati)
- [x] Dove vivono gli asset: `app/assets`, `lib/`, `vendor/`, `app/javascript/packs`
- [x] Turbolinks (e `data-turbolinks="false"`)
- [x] DOM e selettori (`querySelector`, `querySelectorAll`, `insertAdjacentHTML`)
- [x] Caricare un template via Ajax: `remote: true` + `new.js.erb`
- [x] Entrata in dissolvenza (via CSS)
- [x] Form via Ajax: `form_with` remoto, `respond_to` con `format.js`, `create.js.erb`, `fail_create.js.erb`
- [x] Eliminare via Ajax: `remote: true`, `destroy.js.erb`
- [x] Test (102) e prova in un DOM simulato (36 controlli)

## 7. Auto-verifica

1. Perché le richieste Ajax con `remote: true` rispondono con un template `.js.erb` e non `.html.erb`?
2. Cosa fa `<%= j render(@comment) %>` e perché serve `j`?
3. Perché una GET che risponde JavaScript viene rifiutata se non è una richiesta Ajax?
4. Cosa significa "miglioramento progressivo" nel blog?
5. Perché il file CSS in produzione ha una sequenza di caratteri nel nome?
6. Dopo un'azione Ajax, perché non vedi il messaggio `flash`?

<details><summary>Risposte</summary>

1. Il link/form Ajax chiede `Accept: text/javascript`: Rails sceglie il blocco `format.js` e il template `nome_azione.js.erb`; il browser ne **valuta** il codice per modificare la pagina.
2. Renderizza il partial dell'articolo/commento in HTML e lo rende utilizzabile dentro una stringa JavaScript (escape di virgolette, a capo e `</`). Senza `j` le virgolette dell'HTML romperebbero la stringa.
3. Per impedire che un altro sito la includa con `<script src="…">` e legga dati riservati (JavaScript cross-origin). Le richieste Ajax portano l'header `X-Requested-With`, che un `<script>` non può inviare.
4. Il sito funziona senza JavaScript (link normale, pagina con il form, redirect); il JavaScript lo rende più comodo.
5. È l'impronta (digest) del contenuto: se il file cambia cambia il nome, e il browser può tenerlo in cache per sempre senza rischiare di usare una versione vecchia.
6. Il flash vive fino al redirect successivo; con Ajax non c'è un redirect e la pagina non si ricarica. Per questo si crea un avviso con JavaScript.

</details>

---

**Prossimo capitolo**: il **10** tratta **Active Storage**, il sistema di Rails per gestire i file allegati ai modelli: caricamento (per esempio un'immagine di copertina per gli articoli), miniature e validazione dei tipi di file.
