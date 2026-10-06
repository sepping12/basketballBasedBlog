# Capitolo 10 — Active Storage

> **In una frase**: Active Storage è il sistema di Rails per i **file allegati ai modelli** (qui: una **copertina** per ogni articolo): li salva, ne crea versioni ridimensionate (**varianti**/miniature) e li elimina. Basta una riga nel modello, `has_one_attached`.

## 1. Il contesto (la mappa mentale)

Un file non si salva in una colonna della tabella: si salva **su disco** (o su un servizio cloud come Amazon S3), e nel database restano solo due righe che dicono "questo file appartiene a questo record".

```
                 articles                     active_storage_attachments            active_storage_blobs                  storage/ (disco)
        ┌───────────────────────┐       ┌────────────────────────────────┐     ┌───────────────────────────┐     ┌────────────────────┐
        │ id: 5                 │◄──────│ record_type: "Article"         │     │ id: 1                     │     │ ru806izgg…  (file) │
        │ title: …              │ record│ record_id:   5                 │────►│ key: "ru806izgg…"         │────►│ variants/…  (copie)│
        │ (nessuna colonna per  │       │ name: "cover_image"            │blob │ filename, content_type,   │     └────────────────────┘
        │  il file!)            │       │ blob_id: 1                     │     │ byte_size, checksum, …    │
        └───────────────────────┘       └────────────────────────────────┘     └───────────────────────────┘
```

| Pezzo | Cos'è |
|---|---|
| **Blob** | il file in sé: nome, tipo, dimensione, impronta (`checksum`) e la `key` con cui è salvato |
| **Attachment** | il collegamento tra un blob e un record. **Polimorfico**: ha `record_type` ("Article") e `record_id`, così funziona per **qualsiasi** modello con le stesse due tabelle |
| **Service** | dove finiscono i file: `Disk` (cartella `storage/`, in sviluppo), S3, Google Cloud… si sceglie in `config/storage.yml` |
| **Variant** | una **copia ridimensionata** dell'immagine, creata alla prima richiesta e poi riusata |

Il file originale **non si ritocca mai**: le miniature sono copie.

## 2. Cosa ho fatto

| Passo | Comando / file |
|---|---|
| Prerequisito: **ImageMagick** | non c'era; senza `sudo` l'ho messo in `~/.local` (vedi sotto) |
| La gemma per le miniature | in `Gemfile` ho riattivato `gem 'image_processing', '~> 1.2'` → `bundle install` |
| Tabelle di Active Storage | `bin/rails active_storage:install` + `bin/rails db:migrate` |
| Il modello | `has_one_attached :cover_image` in `Article` |
| Il form | `form.file_field :cover_image` + anteprima + checkbox "Rimuovi questa immagine" |
| Il controller | `:cover_image` e `:remove_cover_image` nei `permit` |
| Le viste | partial **`articles/_cover`** (schede e pagina articolo), `show.html.erb`, `_article.html.erb` |
| API JSON | `cover_image_url` (indirizzo dell'originale) |
| Dati d'esempio | 4 copertine a tema basket in `db/seeds/covers/` (le ho generate io), allegate dal seed |
| Test | **129** (27 nuovi) |
| Prove | [capitolo10_esercizi.rb](capitolo10_esercizi.rb) |

### ImageMagick senza `sudo`

Il libro dice `sudo apt-get install imagemagick`. Qui `sudo` chiede una password, quindi ho scaricato l'**AppImage ufficiale** di ImageMagick 7.1.2 in `~/.local/opt/imagemagick/` e creato `~/.local/bin/magick`. **Nel tuo terminale** serve che `~/.local/bin` sia nel `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc     # poi riapri il terminale
magick -version                                               # deve mostrare "ImageMagick 7.1.2…"
```

(In alternativa, con la password: `sudo apt-get install imagemagick`.) Senza ImageMagick il sito **funziona**, ma le copertine non si vedono (le miniature non si possono creare) e **3 test vengono saltati**.

### Dove ho deviato dal libro (e perché)

| Cosa | Libro | Qui | Motivo |
|---|---|---|---|
| Validazione del file | nessuna (la cita solo nell'introduzione) | **tipo** (JPEG/PNG/GIF/WebP) e **dimensione** (≤ 5 MB), messaggi in italiano | Rails 6.0 non ha validazioni integrate; senza, si potrebbe caricare qualsiasi cosa. **SVG rifiutato**: può contenere JavaScript |
| Flag `remove_cover_image` | resta `"1"` dopo l'uso | **si azzera** dopo il `purge` | nel libro, riusando lo stesso oggetto, la copertina allegata subito dopo veniva cancellata (trovato eseguendo gli esempi) |
| Partial | `_article` con `local_assigns.fetch(:cover_image_options, [200, 200])` | partial **`_cover`** con `variant:` e `loading:` come locali | il nostro `_article` è la scheda con un design proprio; la tecnica `local_assigns.fetch` è la stessa |
| Dimensioni | 200×200 e 500×500 con `resize_to_limit` | schede **640×360** (`resize_to_fill`), pagina **1200×800** (`resize_to_limit`) | il tema ha schede 16:9 |
| Caricamento immagini | – | `loading="lazy"` nelle schede, `"eager"` nell'immagine principale | le immagini già visibili vanno caricate subito |
| Elenchi | `Article.all` | `with_attached_cover_image` | evita il problema N+1 (vedi sotto) |
| Testi e `confirm:` | inglese | italiano; `data: { confirm: }` | come nei capitoli precedenti |

## 3. I concetti chiave

### 3.1 `has_one_attached`

```ruby
has_one_attached :cover_image        # un file;  has_many_attached :photos  per più file
```

Ottieni un oggetto con questi metodi (tutti verificati nello script):

| Metodo | Fa |
|---|---|
| `article.cover_image.attached?` | c'è un file? |
| `.attach(io:, filename:, content_type:)` | allega un file |
| `.filename`, `.content_type`, `.byte_size`, `.checksum` | informazioni (dal blob) |
| `.download` | i byte del file |
| `.variant(resize_to_limit: [100, 100])` | una versione ridimensionata |
| `.purge` | elimina l'allegato **e il file** (sincrono); `purge_later` lo fa in un job |
| `.detach` | **scollega** soltanto: il file resta, "orfano" |

Non serve nessuna colonna in `articles`: `Article.column_names.grep(/cover/)` → `[]`.

### 3.2 Il form

```erb
<%= form.file_field :cover_image, accept: "image/jpeg,image/png,…" %>
```

`form_with` passa da solo a **`enctype="multipart/form-data"`**, necessario per inviare file. L'attributo `accept` aiuta l'utente (il selettore file mostra solo le immagini) ma **non è sicurezza**: il controllo vero è nel modello.

Nel controller basta aggiungere `:cover_image` ai `permit`. Il file arriva come `ActionDispatch::Http::UploadedFile`.

**Rimuovere**: la checkbox si chiama `remove_cover_image` ma **non è una colonna**: è un attributo "virtuale" (`attr_accessor`) che il modello legge dopo il salvataggio.

```ruby
attr_accessor :remove_cover_image
after_save :purge_cover_image_if_requested     # se vale "1": cover_image.purge
```

`"1"` perché è il valore che Rails dà a una checkbox spuntata (non spuntata → `"0"`).

### 3.3 Le varianti (miniature)

```erb
<%= image_tag article.cover_image.variant(resize_to_fill: [640, 360]) %>
```

| Trasformazione | Effetto (verificato) |
|---|---|
| `resize_to_limit: [100, 100]` | sta **dentro** il rettangolo, mantiene le proporzioni, **non ingrandisce mai**: 600×400 → 100×67; con `[1000,1000]` resta 600×400 |
| `resize_to_fill: [300, 100]` | riempie le dimensioni **esatte** ritagliando i bordi: → 300×100 |

**Come funziona** (verificato con richieste vere):
1. Nella pagina, `image_tag` produce un indirizzo **firmato**: `/rails/active_storage/representations/…` (la pagina *non* crea la miniatura).
2. Il browser lo richiede; il server **crea** la variante con ImageMagick (la prima volta ~1 secondo) e risponde con un **redirect (302)** al file vero (`/rails/active_storage/disk/…`).
3. Le volte successive la variante esiste già (14 ms).

Risultato per questo blog: originale 1200×630 da 41 KB → scheda 640×360 da 18 KB.

**La variante è identificata dalle sue trasformazioni**: la stessa chiamata dà la stessa `variation.key`, quindi non si ricrea.

### 3.4 Il file viene scritto dopo il commit

Scoperta importante (l'ho vista fallire): `attach` su un record salvato scrive il file **dopo il commit della transazione** (`after_commit`). Dentro una transazione non conclusa il file non esiste ancora, e `download` o le varianti danno `FileNotFoundError`. Per questo lo script di questo capitolo, a differenza degli altri, **non** usa il rollback: crea dati veri e li ripulisce nel blocco `ensure`.

### 3.5 Il ruolo dei job

Dopo l'`attach`, Rails accoda un job (`AnalyzeJob`) che legge **larghezza e altezza** e le salva nei metadati del blob (`{"width"=>600, "height"=>400}`). Anche l'eliminazione di un allegato sostituito (`purge_later`) passa da un job. Di default i job girano **in background** nello stesso processo (adattatore `async`): il Capitolo 13 spiega Active Job.

### 3.6 Validazioni (le abbiamo scritte noi)

```ruby
COVER_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
COVER_MAX_SIZE = 5.megabytes
validate :cover_image_must_be_a_valid_image
```

Verificato: un `.txt` o un `.svg` → "Copertina deve essere un'immagine JPEG, PNG, GIF o WebP"; un PNG "gonfiato" oltre 5 MB → "Copertina è troppo grande (massimo 5 MB)".

⚠️ **Limite noto**: il tipo lo dichiara chi carica. Active Storage guarda prima il **contenuto** del file (con la libreria *Marcel*); ma se non riconosce nulla, **si fida del nome e del tipo dichiarato**: un file di testo chiamato `finta.png` con tipo `image/png` passa la validazione (verificato). Cosa limita il danno: Rails invia `X-Content-Type-Options: nosniff`, serve in download forzato i tipi non-immagine, e le **varianti vengono sempre ricodificate** da ImageMagick (un file finto non produce una miniatura). Per una verifica più dura si può far leggere l'immagine a ImageMagick già in validazione.

### 3.7 Prestazioni: `with_attached_cover_image`

```ruby
@articles = Article.latest_first.includes(:categories).with_attached_cover_image
```

Senza, ogni scheda interroga il database per sapere se ha una copertina: **una query per articolo** (il "problema N+1"). Misurato su 10 articoli: **11 query** senza, **3** con `with_attached_cover_image` (e rimangono 3 anche con 1000 articoli).

### 3.8 Caricamento lazy

`loading="lazy"` fa caricare l'immagine solo quando sta per entrare nello schermo: ottimo per gli elenchi. Per l'immagine **principale**, già visibile in cima alla pagina, è controproducente: lì `loading="eager"`. (Me ne sono accorto guardando gli screenshot: le immagini lazy non comparivano.)

### 3.9 Servizi e produzione

`config/storage.yml` definisce i servizi (`local`, `test`; qui si aggiungerebbero `amazon`, `google`…) e `config.active_storage.service` sceglie quale usare per ambiente. Con `Disk` i file stanno in `storage/`: **in produzione quella cartella deve sopravvivere ai deploy**, e il server deve avere ImageMagick (o libvips). Per questo `storage/` è in `.gitignore`: i file non vanno in git.

## 4. Trappole e scoperte

| Cosa | Spiegazione |
|---|---|
| Nessun file nelle transazioni | upload dopo il commit: dentro un `transaction do … end` non concluso il file non c'è |
| Flag `"1"` che resta | nel libro cancella anche la copertina successiva sullo stesso oggetto; qui azzerato |
| `<%#` multilinea | ho **spezzato** per errore un commento ERB del partial: le righe dopo la chiusura finivano come testo (scuro su scuro) nella pagina. Si vedeva solo guardando l'HTML |
| `fixture_file_upload` | in Rails 6.0 il percorso parte da `test/fixtures` (dalla 6.1 da `test/fixtures/files`): `fixture_file_upload("files/copertina.png")` |
| Variante di un'immagine più piccola | `resize_to_limit` non ingrandisce: 600×400 resta 600×400 |
| Immagini nei JSON | `url_for` dà un percorso relativo; per un indirizzo completo `rails_blob_url` |
| Test senza ImageMagick | 3 test si saltano da soli (`skip`), gli altri passano |
| Ripulire gli orfani | `ActiveStorage::Blob.unattached.find_each(&:purge)` (per esempio dopo un `detach` o un caricamento fallito) |
| Uno dei miei file di prova | i file di `storage/` creati sul sito (le miniature) sono una **cache**: si possono cancellare, si ricreano |

## 5. Come provarlo

```bash
bin/rails server                                     # con ImageMagick nel PATH
# accedi, "Scrivi", scegli un'immagine, pubblica; poi modifica l'articolo e prova "Rimuovi questa immagine"
bin/rails test                                       # 129 test (3 saltati senza ImageMagick)
bin/rails runner capitoli/capitolo10_esercizi.rb
```

Per dare una copertina agli articoli di esempio già presenti non serve fare nulla: `bin/rails db:seed` le ha già allegate.

## 6. Checklist del capitolo

- [x] ImageMagick e `image_processing`
- [x] `rails active_storage:install` + migrazione
- [x] `has_one_attached :cover_image`
- [x] Campo file nel form e `:cover_image` nei `permit`
- [x] Mostrare l'immagine con `image_tag` e `variant` (anche con dimensioni diverse via `local_assigns.fetch`)
- [x] Rimuovere con `remove_cover_image` + `purge`
- [x] Validazione di tipo e dimensione (in più rispetto al libro)
- [x] Evitare l'N+1 con `with_attached_cover_image`
- [x] 129 test; verifica nel browser con screenshot

## 7. Auto-verifica

1. Dove vengono salvati davvero i byte di una copertina? E cosa c'è nel database?
2. Perché `attachments` ha `record_type` e `record_id`?
3. Differenza tra `resize_to_limit` e `resize_to_fill`?
4. Cosa succede la prima volta che un browser chiede la miniatura?
5. Differenza tra `detach` e `purge`?
6. Perché `accept="image/*"` nel form non basta per la sicurezza?
7. A cosa serve `with_attached_cover_image`?

<details><summary>Risposte</summary>

1. In `storage/` (servizio Disk). Nel database: una riga in `active_storage_blobs` (nome, tipo, dimensione, chiave) e una in `active_storage_attachments` che la collega al record.
2. Il collegamento è polimorfico: stesse due tabelle per qualsiasi modello (`Article`, `User`…).
3. `resize_to_limit` sta dentro le dimensioni mantenendo le proporzioni (senza ingrandire); `resize_to_fill` riempie le dimensioni esatte ritagliando.
4. Il server crea la variante con ImageMagick, la salva e risponde con un redirect al file; dalla seconda volta la variante esiste già.
5. `detach` scollega soltanto (il blob e il file restano); `purge` elimina allegato, blob e file.
6. È solo un suggerimento per il selettore del browser: chi invia una richiesta a mano può mandare qualsiasi file. Il controllo vero è la validazione nel modello.
7. Carica in anticipo gli allegati di tutti gli articoli in 2 query, invece di una per articolo (N+1).

</details>

---

**Prossimo capitolo**: l'**11** tratta **Action Text**, il sistema di Rails per il **testo formattato** (grassetto, elenchi, link, immagini incorporate) con un editor nel browser: lo useremo per il testo degli articoli al posto della semplice area di testo.
