# Capitolo 5 — Lavorare con un database: Active Record

> **In una frase**: Active Record è il pezzo di Rails che ti fa leggere e scrivere nel database usando oggetti Ruby invece di SQL. Qui impari le 4 operazioni di base (**CRUD**) dalla console.

## 1. Il contesto (la mappa mentale)

Nel Capitolo 3 lo scaffold faceva già tutto questo per te. Qui guardi **dentro**.

Active Record è un **ORM** (*Object-Relational Mapping*): collega due mondi.

| Database | Ruby |
|---|---|
| **tabella** `articles` | **classe** `Article` |
| **riga** della tabella | **oggetto** (un `Article`) |
| **colonna** `title` | **attributo** `article.title` |

Non scrivi nessuna configurazione: se la tabella si chiama `articles` e la classe `Article < ApplicationRecord`, Rails legge le colonne e crea da solo i metodi `title`, `title=`, `body`... (DRY: gli attributi si definiscono in un solo posto, il database).

```
Article < ApplicationRecord < ActiveRecord::Base      ← da qui arrivano gli ~400 metodi gratis
```

**Le due convenzioni** da sapere: classe **singolare** ↔ tabella **plurale**, e ogni tabella ha una colonna `id` (chiave primaria).

| Classe | Tabella |
|---|---|
| `Event` | `events` |
| `Person` | `people` (Rails conosce i plurali irregolari) |
| `OrderItem` | `order_items` |

**Dove usi tutto questo nel blog:** quello che provi in console è esattamente ciò che fa il controller.

| In console | Nel controller (`articles_controller.rb`) | SQL generato |
|---|---|---|
| `Article.all` / `Article.latest_first` | `index` | `SELECT * FROM articles ...` |
| `Article.find(id)` | `set_article` | `SELECT ... WHERE id = ?` |
| `Article.new` | `new` | (niente: non tocca il DB) |
| `Article.new(params)` + `save` | `create` | `INSERT INTO articles ...` |
| `article.update(params)` | `update` | `UPDATE articles SET ... WHERE id = ?` |
| `article.destroy` | `destroy` | `DELETE FROM articles WHERE id = ?` |

## 2. Cosa ho fatto

Ho eseguito **tutti gli esempi del capitolo** nello script [capitolo5_esercizi.rb](capitolo5_esercizi.rb), che stampa il codice e il risultato come farebbe la console:

```bash
bin/rails runner capitoli/capitolo5_esercizi.rb     # esegue gli esercizi
bin/rails console                                   # per provare a mano (exit per uscire)
bin/rails console --sandbox                         # come sopra, ma al termine annulla TUTTE le modifiche
```

**Una differenza importante dal libro.** Il libro inizia con `rails db:reset`, che **cancella il database** (e ricarica `db/seeds.rb`, cioè i tuoi articoli di esempio). Non l'ho lanciato sul database di sviluppo. Lo script gira dentro una **transazione** che alla fine viene annullata (`raise ActiveRecord::Rollback`): ho creato, modificato ed eliminato articoli "veri", e al termine il blog aveva ancora i suoi 4 articoli (verificato: 4 prima, 4 dopo, stesso id massimo). Il comando `db:reset` l'ho provato solo sul database di **test**: `RAILS_ENV=test bin/rails db:reset`.

Per questo gli id nei miei output (5, 10, 13...) sono diversi da quelli del libro (1, 2, 3...): il concetto è identico.

## 3. Le operazioni CRUD, con i risultati veri

### C — Create (creare)

```ruby
article = Article.new                  # oggetto in memoria, NON ancora nel DB
article.new_record?                    # => true
article.title = 'RailsConf'            # writer: modifica solo l'oggetto
article.save                           # => true   ora esegue INSERT
article.new_record?                    # => false  e ha un id
```

SQL generato da `save` (visibile nell'output dello script):

```
INSERT INTO "articles" ("title", "body", "published_at", "created_at", "updated_at") VALUES (?, ?, ?, ?, ?)
```

| Modo | Fa | Restituisce |
|---|---|---|
| `Article.new(title: "...", body: "...")` + `save` | crea l'oggetto, poi lo salvi **tu** | `save` → `true`/`false` |
| `Article.create(title: "...", body: "...")` | crea **e salva** in un colpo | **l'oggetto** creato |

Punti chiave:
- `new` da solo **non salva**: se dimentichi `save`, il record non esiste.
- `article.title = 'x'` è un **metodo travestito**: equivale a `article.title=('x')`.
- Gli hash passati come ultimo argomento non vogliono le graffe: `Article.create(title: "...")`.
- `nil` è il "nulla": un articolo nuovo ha tutti gli attributi a `nil`, anche l'`id`.
- `created_at` e `updated_at` li compila Rails da solo.

### R — Read (leggere)

| Cosa vuoi | Codice | Risultato | Se non trova |
|---|---|---|---|
| Uno per `id` | `Article.find(3)` | l'oggetto | **solleva** `RecordNotFound` |
| Più di uno per `id` | `Article.find([4, 5])` | array di oggetti | solleva |
| Il primo / l'ultimo | `Article.first` / `Article.last` | l'oggetto | `nil` |
| Tutti | `Article.all` | una **Relation** | vuota |
| Con una condizione | `Article.where(title: 'RailsConf')` | una **Relation** | vuota (`[]`) |
| Ordinati | `Article.order(:title)` | una **Relation** | |
| Ordinati al contrario | `Article.order(published_at: :desc)` | una **Relation** | |

**Cos'è una `Relation`.** `Article.all`, `where` e `order` non restituiscono un array ma una `ActiveRecord::Relation`: una **query non ancora eseguita**. Si comporta come un array (`.size`, `[0]`, `.each`), ma puoi **concatenare** altri metodi prima di eseguirla:

```ruby
Article.order(:title).limit(2)
Article.order(:title).limit(2).to_sql
# => "SELECT \"articles\".* FROM \"articles\" ORDER BY \"articles\".\"title\" ASC LIMIT 2"
```

È il **lazy loading**: il database viene interrogato solo quando serve davvero (per esempio al `each`). È la base di tutti gli *scope* come `Article.latest_first` del blog.

**Gestire un record inesistente:**

```ruby
begin
  Article.find(1037)
rescue ActiveRecord::RecordNotFound
  puts "We couldn't find that record"
end
```

In un controller, Rails trasforma da solo il `RecordNotFound` in una pagina **404**. In più c'è `Article.find_by(id: 1037)`, che restituisce `nil` invece di sollevare (non è nel capitolo ma lo troverai di continuo).

⚠️ **`first` non significa "il più vecchio"**: dipende dall'ordine predefinito del database. Se ti serve la certezza, specifica `order`. (Nel mio blog `Article.first` era l'id 5, perché i primi 4 erano già stati eliminati.)

### U — Update (aggiornare)

```ruby
article = Article.first               # prima lo recuperi
article.title = "Rails 6 is great"
article.save                           # => true   esegue UPDATE
# oppure in un colpo solo:
article.update(title: "RailsConf2020", published_at: 1.day.ago)   # => true
```

SQL: `UPDATE "articles" SET "title" = ?, "published_at" = ?, "updated_at" = ? WHERE "articles"."id" = ?`. Nota: Rails aggiorna **solo** le colonne cambiate (più `updated_at`).

⚠️ **Il libro usa `update_attributes`: è obsoleto.** In Rails 6.0 è deprecato e in 6.1 è stato **rimosso**. Si usa `update`, che fa la stessa cosa. Se lo trovi in un progetto vecchio, sostituiscilo.

`update` è un metodo di **istanza**: devi prima avere l'oggetto. `create` invece è di **classe**.

### D — Delete (eliminare)

| Metodo | Su cosa agisce | Callback e validazioni | Restituisce |
|---|---|---|---|
| `article.destroy` | un oggetto già caricato | **sì** | l'oggetto (congelato) |
| `Article.destroy(5)` / `Article.destroy([2, 3])` | classe: trova ed elimina | **sì** | oggetto / array di oggetti |
| `Article.delete(5)` / `Article.delete([5, 6])` | classe: DELETE diretto | **no** | **numero** di righe eliminate |
| `Article.delete_by("published_at < '2011-01-01'")` | classe: per condizione | no | numero di righe |

Cose da ricordare:
- Dopo `destroy` l'oggetto resta in memoria ma è **congelato**: `article.destroyed?` → `true`, `article.frozen?` → `true`. Puoi **leggere** `article.title`, ma modificarlo dà `RuntimeError: Can't modify frozen hash`.
- **`delete` vuole un array esplicito**: `Article.delete([1, 2, 3])` funziona, `Article.delete(1, 2, 3)` dà `ArgumentError: wrong number of arguments (given 3, expected 1)`. (`find` e `destroy` accettano entrambe le forme.)
- `delete` restituisce `0` se le righe non esistono: non è un errore.
- **`destroy` esegue i callback**, `delete` no: nei progetti veri si usa quasi sempre `destroy`, perché i callback (Capitolo 6) possono fare pulizie importanti.

## 4. Quando i modelli "si comportano male": errori di validazione

Ogni oggetto Active Record ha una collezione `errors`:

```ruby
article = Article.new
article.errors.any?          # => false   ← le validazioni NON sono ancora scattate!
article.save                 # => false   ← qui scattano, e il record non viene salvato
article.errors.any?          # => true
article.errors.full_messages # => ["Titolo è obbligatorio", "Testo è obbligatorio"]
article.errors.messages[:title]   # => ["è obbligatorio"]
article.errors.size          # => 2
article.valid?               # => false   ← controlla SENZA salvare
```

È esattamente quello che mostra `_form.html.erb` nel blog con `article.errors.full_messages`. La differenza dal libro ("Title can't be blank") è che nel blog abbiamo tradotto i messaggi (passo 9).

⚠️ **`errors` è vuoto finché non fai `save` o `valid?`**: un errore tipico è controllare `errors.any?` troppo presto.

## 5. Le trappole più comuni

| Trappola | Cosa succede | Rimedio |
|---|---|---|
| `Article.new(...)` senza `save` | niente nel DB | usa `create`, oppure `save` |
| `save` restituisce `false` e lo ignori | il record non viene salvato in silenzio | controlla il risultato; `save!` solleva un errore |
| `find` con id inesistente | `RecordNotFound` | `find_by` (→ `nil`) o `rescue` |
| `where(...)` e poi usare come un oggetto | è una `Relation`, non un `Article` | aggiungi `.first` o `.to_a` |
| `Article.first` "il più vecchio" | non è garantito | `order(:created_at).first` |
| `delete(1, 2, 3)` | `ArgumentError` | `delete([1, 2, 3])` |
| `update_attributes` | obsoleto/rimosso | `update` |
| `db:reset` | **cancella il DB** di sviluppo | usalo solo se non hai dati da perdere |

## 6. Consiglio pratico per il lavoro

Prima di provare codice che modifica dati (soprattutto se non sei sicuro), apri la console in modalità sandbox:

```bash
bin/rails console --sandbox
```

Tutte le modifiche vengono annullate quando esci. Il tuo database di sviluppo non si sporca.

## 7. Checklist del capitolo

- [x] ORM: tabella ↔ classe, riga ↔ oggetto, colonna ↔ attributo
- [x] Convenzioni sui nomi (`tableize`, `classify`) e colonna `id`
- [x] Console: `column_names`, ispezione della classe, `new_record?`, `attributes`
- [x] Creare: `new` + `save`, `new` con hash, `create`
- [x] Leggere: `find`, `first`, `last`, `all`, `order`, `where`; `RecordNotFound` gestito con `rescue`
- [x] Aggiornare: `save` e `update`
- [x] Eliminare: `destroy` (istanza e classe), `delete`, `delete_by`; oggetto congelato
- [x] Errori di validazione: `errors`, `full_messages`, `valid?`
- [x] Database di sviluppo lasciato intatto (rollback)

## 8. Auto-verifica

1. Cosa restituiscono `Article.new` e `Article.create`? Quale dei due scrive nel database?
2. Che differenza c'è tra `Article.find(1037)` e `Article.find_by(id: 1037)`?
3. Perché `Article.where(title: "X")` non è un array, e a cosa serve?
4. Differenza tra `destroy` e `delete`?
5. Perché `article.errors.any?` può essere `false` anche su un articolo senza titolo?

<details><summary>Risposte</summary>

1. `new` restituisce un oggetto non salvato; `create` restituisce l'oggetto già salvato. Scrive nel DB solo `create` (o `new` seguito da `save`).
2. `find` solleva `RecordNotFound`, `find_by` restituisce `nil`.
3. È una `Relation`: una query non ancora eseguita, a cui puoi concatenare altri metodi (`order`, `limit`...). Viene eseguita solo quando serve.
4. `destroy` carica l'oggetto ed esegue validazioni/callback; `delete` fa un DELETE diretto, senza callback, e restituisce il numero di righe.
5. Perché le validazioni scattano solo con `save` o `valid?`: prima, `errors` è vuoto.

</details>

---

**Prossimo capitolo**: il 6 (Active Record avanzato) aggiunge le **associazioni** (per esempio i commenti collegati agli articoli), query avanzate, validazioni e callback. È quello che ti serve di più per i task veri.
