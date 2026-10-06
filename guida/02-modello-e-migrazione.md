# Passo 2 — Il modello Article e la sua migrazione

**Obiettivo**: creare il modello `Article`, scrivere la migrazione che crea la tabella `articles`, eseguirla e capire come annullarla.

**Nel libro**: "Creare il modello Article" e "Creare una tabella nel database".

---

## 2.1 Convenzioni sui nomi (da sapere a memoria)

| Cosa | Convenzione | Esempio |
|---|---|---|
| Modello (classe) | singolare, CamelCase | `Article`, `BlogImage`, `Person` |
| File del modello | singolare, snake_case | `app/models/article.rb`, `blog_image.rb` |
| Tabella | plurale, snake_case | `articles`, `blog_images`, `people` |
| Controller | plurale | `ArticlesController` |

Rails conosce i plurali irregolari dell'inglese: `Person` → `people`, non `persons`. Puoi verificarlo in `bin/rails console` con `"person".pluralize`.

- **CamelCase**: ogni parola con la maiuscola, senza spazi → `BlogImage`.
- **snake_case**: tutto minuscolo, con underscore → `blog_image`.

**Per il lavoro**: se rispetti le convenzioni, Rails collega da solo modello ↔ tabella ↔ controller ↔ viste. Se non le rispetti devi configurare tutto a mano: rispettale.

## 2.2 Generare il modello

```bash
bin/rails generate model Article
```

Output reale:

```
      invoke  active_record
      create    db/migrate/20261001123550_create_articles.rb
      create    app/models/article.rb
      invoke    test_unit
      create      test/models/article_test.rb
      create      test/fixtures/articles.yml
```

| File creato | A cosa serve |
|---|---|
| `db/migrate/20261001123550_create_articles.rb` | la **migrazione** che creerà la tabella |
| `app/models/article.rb` | il modello: per ora una classe vuota |
| `test/models/article_test.rb` | dove scrivere i test del modello (Capitolo 16) |
| `test/fixtures/articles.yml` | dati finti usati dai test |

Il numero `20261001123550` è un **timestamp** (anno-mese-giorno-ora-minuti-secondi). Rende unico il nome del file e stabilisce l'ordine di esecuzione, anche quando più sviluppatori creano migrazioni in parallelo.

Il modello generato:

```ruby
class Article < ApplicationRecord
end
```

È vuoto, eppure saprà già leggere e scrivere tutte le colonne della tabella `articles`. Le scopre da solo leggendo il database: è **Active Record** (Capitolo 5).

> Se la tabella esiste già (per esempio in un DB ereditato), puoi generare il modello senza migrazione con `bin/rails generate model Article --no-migration`.

## 2.3 Scrivere la migrazione

Appena generata, la migrazione è "vuota":

```ruby
class CreateArticles < ActiveRecord::Migration[6.0]
  def change
    create_table :articles do |t|

      t.timestamps
    end
  end
end
```

È stata completata così (Listato 3-3):

```ruby
class CreateArticles < ActiveRecord::Migration[6.0]
  def change
    create_table :articles do |t|
      t.string   :title
      t.text     :body
      t.datetime :published_at
      t.timestamps
    end
  end
end
```

| Riga | Significato |
|---|---|
| `ActiveRecord::Migration[6.0]` | la migrazione è scritta per le regole di Rails 6.0 |
| `def change` | Rails sa eseguire il contenuto **e** sa invertirlo da solo (rollback) |
| `create_table :articles do \|t\|` | crea la tabella `articles`; `t` rappresenta la tabella dentro il blocco |
| `t.string :title` | colonna `title` di tipo stringa breve (`varchar`, per titoli, nomi, email...) |
| `t.text :body` | colonna `body` di tipo testo lungo |
| `t.datetime :published_at` | colonna data + ora |
| `t.timestamps` | crea `created_at` e `updated_at`, che Rails compila da solo |

La colonna `id` (chiave primaria, numero auto-incrementale) non si scrive: Rails la aggiunge automaticamente.

Tipi di colonna più usati: `string`, `text`, `integer`, `decimal`, `float`, `boolean`, `date`, `datetime`, `references` (per le relazioni).

> **Scorciatoia**: lo stesso risultato si ottiene subito con
> `bin/rails generate model Article title:string body:text published_at:datetime`.
> Il generatore scrive le colonne nella migrazione per te.

## 2.4 Eseguire la migrazione

```bash
bin/rails db:migrate
```

```
== 20261001123550 CreateArticles: migrating ===================================
-- create_table(:articles)
   -> 0.0056s
== 20261001123550 CreateArticles: migrated (0.0057s) ==========================
```

Cosa è successo:

1. Rails ha guardato in `db/migrate/` quali migrazioni non sono ancora state eseguite.
2. Ha eseguito `CreateArticles`.
3. Ha scritto il suo numero nella tabella speciale `schema_migrations`.
4. Ha aggiornato **`db/schema.rb`**.

Se lo rilanci, non stampa niente: la migrazione risulta già eseguita.

Verifica nel database:

```bash
sqlite3 db/development.sqlite3 '.tables' '.schema articles' 'select * from schema_migrations'
```

```
ar_internal_metadata  articles              schema_migrations
CREATE TABLE IF NOT EXISTS "articles" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "title" varchar, "body" text, "published_at" datetime,
  "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
20261001123550
```

Ecco l'`id` aggiunto da Rails, e la `varchar` che corrisponde a `t.string`.

Lo stato delle migrazioni si vede anche con:

```bash
bin/rails db:migrate:status
```

```
 Status   Migration ID    Migration Name
--------------------------------------------------
   up     20261001123550  Create articles
```

`up` = eseguita, `down` = non eseguita.

### `db/schema.rb`

```ruby
ActiveRecord::Schema.define(version: 2026_10_01_123550) do
  create_table "articles", force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.datetime "published_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end
end
```

È la **fotografia attuale** del database, generata automaticamente. **Non va modificata a mano**: si cambia solo scrivendo nuove migrazioni.

**Per il lavoro**: `schema.rb` va sempre committato in git. Quando un collega clona il progetto, può creare il DB con `bin/rails db:setup` (che usa `schema.rb`) invece di eseguire centinaia di migrazioni. Nelle code review, il diff di `schema.rb` mostra subito cosa cambia nel DB.

## 2.5 Tornare indietro: `db:rollback`

```bash
bin/rails db:rollback
```

```
== 20261001123550 CreateArticles: reverting ===================================
-- drop_table(:articles)
   -> 0.0050s
== 20261001123550 CreateArticles: reverted (0.0107s) ==========================
```

Rails ha eseguito un `drop_table` che **nessuno ha scritto**: l'ha dedotto da `create_table` dentro `change`. Dopo il rollback, `.tables` mostra solo `ar_internal_metadata schema_migrations`.

Poi si riesegue, per ripristinare la tabella:

```bash
bin/rails db:migrate
```

**Per il lavoro**:
- `db:rollback` annulla **l'ultima** migrazione; `db:rollback STEP=3` le ultime tre.
- Il rollback **cancella i dati** contenuti nelle tabelle/colonne rimosse. In sviluppo va bene, in produzione si usa con molta cautela.
- Regola d'oro: **non modificare una migrazione già eseguita da altri** (colleghi, server). Scrivine una nuova. Una migrazione già eseguita non verrebbe rieseguita, e i database diventerebbero diversi tra loro.
- Se una migrazione non ancora condivisa è sbagliata: `db:rollback`, la correggi, `db:migrate`.

---

## 🧠 Domande di verifica

1. Il modello `Category`: come si chiama la tabella? E il file del modello?
2. Perché il file della migrazione inizia con un numero lungo?
3. Che differenza c'è tra il file di migrazione e `db/schema.rb`?
4. Perché con `change` non devi scrivere il codice del rollback?
5. Hai eseguito una migrazione, l'hai già pushata e i colleghi l'hanno eseguita. Ti accorgi di un errore: cosa fai?

<details><summary>Risposte</summary>

1. Tabella `categories`, file `app/models/category.rb`.
2. È un timestamp: rende unico il nome e fissa l'ordine di esecuzione.
3. La migrazione è un *passo* (una modifica); `schema.rb` è il *risultato* di tutti i passi, cioè lo stato attuale.
4. Rails sa invertire automaticamente le operazioni più comuni (`create_table` ↔ `drop_table`, `add_column` ↔ `remove_column`).
5. Scrivi una **nuova** migrazione che corregge l'errore.

</details>
