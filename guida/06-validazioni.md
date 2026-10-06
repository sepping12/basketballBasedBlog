# Passo 6 — Le validazioni

**Obiettivo**: impedire il salvataggio di articoli senza titolo o senza testo.

**Nel libro**: "Aggiungere le validazioni".

---

## 6.1 Il problema

Prima di aggiungere validazioni, è stato inviato il form con tutti i campi vuoti:

```
POST vuoto -> 302 http://localhost:3000/articles/2
```

Redirect alla pagina show: **l'articolo vuoto è stato salvato**. Nel database:

```ruby
{"id"=>2, "title"=>"", "body"=>"", "published_at"=>nil, "excerpt"=>"", "location"=>"", ...}
```

Il database accetta qualsiasi cosa: nessuno gli ha detto che il titolo è obbligatorio.

## 6.2 La soluzione: una riga nel modello

[app/models/article.rb](../app/models/article.rb) (Listato 3-5):

```ruby
class Article < ApplicationRecord
  validates :title, :body, presence: true
end
```

- `validates` = "controlla questi campi prima di salvare";
- `:title, :body` = i campi da controllare;
- `presence: true` = non devono essere vuoti (`nil`, `""` e una stringa di soli spazi contano tutti come vuoti).

**Perché nel modello e non nel controller o nel form?** In Rails le regole sui dati sono responsabilità del **modello**. Così valgono *ovunque* si salvi un `Article`: dal form web, dall'API JSON, dalla console, da un import o da un job in background. Se la regola fosse nel form, l'API JSON la scavalcherebbe.

> 🔄 **Aggiornamento (passo 9 e Capitolo 6)**: il messaggio è stato tradotto in `config/locales/errori.yml` (`blank: "è obbligatorio"`), quindi ora l'errore è *"Titolo è obbligatorio"*. Il modello resta `validates :title, :body, presence: true`: cambia solo il testo.

## 6.3 Il risultato

Stesso invio del form vuoto, dopo la modifica (senza riavviare il server):

```
POST vuoto -> 422
```

Nessun redirect: il form viene mostrato di nuovo con:

```
2 errors prohibited this article from being saved:
  • Title can't be blank
  • Body can't be blank
```

I campi Title e Body sono evidenziati in rosso: Rails li avvolge in un `<div class="field_with_errors">`, che `scaffolds.scss` colora di rosso.

Cosa succede dietro le quinte, nell'azione `create`:

```ruby
@article = Article.new(article_params)
if @article.save            # ← save esegue le validazioni; se falliscono restituisce false e NON scrive nel DB
  redirect_to @article      #    successo → redirect
else
  render :new, status: :unprocessable_entity   # ← fallimento → ri-mostra il form (con i dati già inseriti) + codice 422
end
```

## 6.4 Provarlo dalla console

Le validazioni si possono provare senza browser:

```bash
bin/rails console
```

```ruby
a = Article.new
a.valid?                 # => false
a.errors.full_messages   # => ["Title can't be blank", "Body can't be blank"]
a.save                   # => false  (non salva)
a.title = "Ciao"
a.body  = "Testo"
a.valid?                 # => true
```

Durante l'esercizio, l'articolo vuoto numero 2 del punto 6.1 è stato poi cancellato con `Article.find(2).destroy`.

**Per il lavoro**:
- `save` restituisce `true`/`false`; `save!` invece solleva un'eccezione se non è valido. Nei controller si usa `save`, negli script e nei test spesso `save!`.
- Le validazioni del modello **non bastano** contro i dati duplicati in caso di richieste simultanee. Per l'unicità servono anche un indice `unique` nel DB (con una migrazione) **e** `validates :email, uniqueness: true`.
- Altre validazioni comuni (Capitolo 6):

```ruby
validates :title, length: { maximum: 120 }
validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
validates :price, numericality: { greater_than: 0 }
validates :status, inclusion: { in: %w[draft published] }
```

---

## 🧠 Domande di verifica

1. Perché la validazione sta nel modello e non nel form HTML?
2. Cosa restituisce `@article.save` se la validazione fallisce? Scrive nel DB?
3. Perché, dopo un errore, il form mostra ancora i dati che avevi scritto?
4. Che differenza c'è tra `save` e `save!`?

<details><summary>Risposte</summary>

1. Così vale per qualsiasi via di salvataggio (web, API, console, job), non solo per quel form.
2. `false`, e non scrive niente nel DB.
3. Perché `render :new` usa lo stesso oggetto `@article` (non salvato) che contiene già i valori inviati.
4. `save` restituisce `false`; `save!` solleva `ActiveRecord::RecordInvalid`.

</details>
