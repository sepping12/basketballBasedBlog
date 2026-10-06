# Passo 5 — Aggiungere campi: `excerpt` e `location`

**Obiettivo**: aggiungere due colonne a una tabella che esiste già (e che contiene dati) usando una nuova migrazione, poi aggiornare le pagine rigenerando lo scaffold.

**Nel libro**: "Aggiungere altri campi".

---

## 5.1 Il generatore di migrazioni

Questa volta non creiamo un modello: modifichiamo una tabella esistente. Si usa il generatore di sole migrazioni:

```bash
bin/rails generate migration add_excerpt_and_location_to_articles excerpt:string location:string
```

```
      invoke  active_record
      create    db/migrate/20261001123655_add_excerpt_and_location_to_articles.rb
```

File generato (Listato 3-4):

```ruby
class AddExcerptAndLocationToArticles < ActiveRecord::Migration[6.0]
  def change
    add_column :articles, :excerpt, :string
    add_column :articles, :location, :string
  end
end
```

**Il trucco del nome**: il corpo è stato scritto da Rails perché il nome segue lo schema `add_<qualcosa>_to_<tabella>`. Rails legge `to_articles`, capisce che la tabella è `articles` e scrive un `add_column` per ogni `campo:tipo`.

Nomi che Rails riconosce:

| Nome della migrazione | Cosa genera |
|---|---|
| `add_xxx_to_articles campo:tipo` | `add_column :articles, :campo, :tipo` |
| `remove_xxx_from_articles campo:tipo` | `remove_column :articles, :campo, :tipo` |
| `create_comments campo:tipo` | `create_table :comments` con le colonne |
| qualsiasi altro nome | `def change` vuoto, da scrivere a mano |

`add_column :articles, :excerpt, :string` = (tabella, nome colonna, tipo).

## 5.2 Eseguirla

```bash
bin/rails db:migrate
```

```
== 20261001123655 AddExcerptAndLocationToArticles: migrating ==================
-- add_column(:articles, :excerpt, :string)
   -> 0.0049s
-- add_column(:articles, :location, :string)
   -> 0.0033s
== 20261001123655 AddExcerptAndLocationToArticles: migrated (0.0084s) =========
```

`db/schema.rb` ora contiene:

```ruby
  create_table "articles", force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.datetime "published_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "excerpt"
    t.string "location"
  end
```

**L'articolo "Beginning Rails 6" creato al passo 4 c'è ancora**: le nuove colonne valgono semplicemente `nil`. Questo è il punto chiave: una migrazione **modifica** il DB senza ricrearlo, quindi i dati restano. In produzione funziona allo stesso modo.

Abbiamo modificato la tabella con una **nuova** migrazione, senza toccare quella vecchia: è la regola d'oro vista al passo 2.

## 5.3 Aggiornare le pagine rigenerando lo scaffold

La tabella ha le nuove colonne, ma form e pagine non le mostrano ancora. Il libro le aggiunge rigenerando lo scaffold con tutti i campi.

Prima bisogna cancellare tre file, altrimenti il generatore si ferma perché esistono già:

```bash
rm app/models/article.rb app/controllers/articles_controller.rb app/helpers/articles_helper.rb
```

Poi:

```bash
bin/rails generate scaffold Article title:string location:string excerpt:string \
  body:text published_at:datetime --no-migration --force
```

- `--no-migration`: **fondamentale**. La tabella esiste già e le colonne le ha aggiunte la migrazione del 5.1: non vogliamo una seconda `create_articles`.
- `--force`: sovrascrive i file in conflitto senza chiedere. Nel libro invece Rails chiede conferma e si risponde `Y` a ogni file.
- L'ordine dei campi nel comando è l'ordine in cui compaiono nel form.

Output (estratto):

```
      create    app/models/article.rb
       force      app/views/articles/index.html.erb       ← sovrascritto
   identical      app/views/articles/edit.html.erb        ← già uguale, non toccato
       force      app/views/articles/show.html.erb
       force      app/views/articles/_form.html.erb
      create    app/controllers/articles_controller.rb
      ...
```

`force` = sovrascritto, `identical` = già uguale, `create` = nuovo.

Il form [app/views/articles/_form.html.erb](../app/views/articles/_form.html.erb) ora ha i campi Location ed Excerpt. Il controller ne accetta i valori:

```ruby
params.require(:article).permit(:title, :location, :excerpt, :body, :published_at)
```

Durante l'esercizio l'articolo 1 è stato modificato da `/articles/1/edit` aggiungendo location "Bowling Green, KY" ed excerpt "Un assaggio di Rails":

```
PATCH /articles/1 -> 302 http://localhost:3000/articles/1
```

## 5.4 Per il lavoro: come si fa davvero

Rigenerare lo scaffold **cancella le personalizzazioni** fatte a mano nei file sovrascritti. Il libro lo fa solo a scopo didattico. In un progetto vero, dopo la migrazione si modificano a mano tre punti:

1. `_form.html.erb`: aggiungi i campi (`form.text_field :excerpt`);
2. `show.html.erb` / `index.html.erb`: mostrali;
3. il controller, in `article_params`: aggiungi `:excerpt, :location` al `permit`.

**Il punto 3 è quello che si dimentica più spesso.** Il sintomo: il form viene inviato, ma il nuovo campo non si salva e nel log compare `Unpermitted parameter: :excerpt`.

---

## 🧠 Domande di verifica

1. Perché è stata scritta una nuova migrazione invece di modificare `create_articles`?
2. Cosa succede ai dati già presenti quando si aggiunge una colonna?
3. Cosa genera `bin/rails g migration remove_location_from_articles location:string`?
4. Cosa sarebbe successo rigenerando lo scaffold **senza** `--no-migration`?
5. Hai aggiunto un campo al form ma non viene salvato: dove guardi?

<details><summary>Risposte</summary>

1. Quella migrazione era già stata eseguita: non verrebbe rieseguita. Le modifiche vanno sempre in una nuova migrazione.
2. Restano. La nuova colonna vale `nil` (o il default, se ne indichi uno).
3. `remove_column :articles, :location, :string`. Il tipo serve a Rails per poter ricreare la colonna in caso di rollback.
4. Sarebbe stata creata un'altra migrazione `create_articles`, che al `db:migrate` avrebbe fallito perché la tabella esiste già.
5. In `article_params` nel controller (il `permit`) e nel log del server (`Unpermitted parameter`).

</details>
