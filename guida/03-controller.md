# Passo 3 — Generare il controller

**Obiettivo**: creare il controller `articles`, che riceverà le richieste del browser per gli articoli.

**Nel libro**: "Generare un controller".

---

## 3.1 Il comando

```bash
bin/rails generate controller articles
```

Il nome è al **plurale**: il controller gestisce *gli* articoli (la collezione), il modello rappresenta *un* articolo.

Output reale:

```
      create  app/controllers/articles_controller.rb
      invoke  erb
      create    app/views/articles
      invoke  test_unit
      create    test/controllers/articles_controller_test.rb
      invoke  helper
      create    app/helpers/articles_helper.rb
      invoke    test_unit
      invoke  assets
      invoke    scss
      create      app/assets/stylesheets/articles.scss
```

`invoke` = "chiamo un sotto-generatore", `create` = "creo questo file/cartella".

## 3.2 I file creati

| File | A cosa serve |
|---|---|
| `app/controllers/articles_controller.rb` | il controller: riceve le richieste e decide la risposta |
| `app/views/articles/` | cartella **vuota** per i template delle viste di questo controller |
| `test/controllers/articles_controller_test.rb` | test funzionali del controller (Capitolo 16) |
| `app/helpers/articles_helper.rb` | metodi di utilità per le viste (Capitoli 7-8) |
| `app/assets/stylesheets/articles.scss` | CSS (in sintassi SASS) per queste pagine |

Il controller generato è vuoto:

```ruby
class ArticlesController < ApplicationController
end
```

Eredita da `ApplicationController` (in `app/controllers/application_controller.rb`). Tutto quello che metti lì vale per tutti i controller dell'app: autenticazione, gestione errori, ecc.

## 3.3 Il collegamento controller ↔ viste

La convenzione è:

```
ArticlesController#index  →  app/views/articles/index.html.erb
ArticlesController#show   →  app/views/articles/show.html.erb
```

Quando un'azione finisce senza dire cosa mostrare, Rails cerca automaticamente il template `app/views/<controller>/<azione>.html.erb`.

> **SASS/SCSS**: linguaggio che si compila in CSS e aggiunge variabili, annidamento, ecc. Rails lo compila da solo tramite l'asset pipeline.

**Per il lavoro**: puoi generare il controller già con le azioni:

```bash
bin/rails generate controller articles index show
```

In questo caso il generatore crea anche i metodi, le viste `index.html.erb` e `show.html.erb` e le route `get 'articles/index'`. Nei progetti veri però le route si scrivono quasi sempre con `resources` (vedi passo 4).

Un controller da solo non è raggiungibile dal browser: serve una **route** in `config/routes.rb`. Lo vediamo nel prossimo passo.

---

## 🧠 Domande di verifica

1. Perché il controller si chiama `articles` (plurale) e il modello `Article` (singolare)?
2. In quale file Rails cerca il template dell'azione `edit` di `ArticlesController`?
3. Cosa manca perché il controller sia raggiungibile da un URL?

<details><summary>Risposte</summary>

1. Convenzione: il controller gestisce la risorsa "articoli" nel suo insieme, il modello descrive un singolo record.
2. `app/views/articles/edit.html.erb`.
3. Una route in `config/routes.rb`.

</details>
