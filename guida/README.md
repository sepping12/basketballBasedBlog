# Guida all'esercizio Blog (Beginning Rails 6, Capitolo 3)

> I passi 1-7 seguono il libro. Il **passo 9** va oltre: il blog è stato ridisegnato (tema basket, landing page, navbar). Nei passi 1-7 il codice è mostrato com'era *prima* della grafica: dove è cambiato, c'è una nota.

L'esercizio è stato eseguito per intero su questo progetto. Ogni file spiega un passo. Dentro trovi:

- **Comandi**: esattamente quelli lanciati;
- **Output reale**: copiato dal terminale di questo progetto, non dal libro;
- **Spiegazione**: cosa è successo e perché;
- **Per il lavoro**: le cose che userai davvero nei progetti Rails;
- **Domande di verifica**: per controllare di aver capito.

> 📘 **Riassunti per capitolo** (corti, con il contesto): [capitoli/capitolo3.md](../capitoli/capitolo3.md) [capitoli/capitolo4.md](../capitoli/capitolo4.md) e [capitoli/capitolo5.md](../capitoli/capitolo5.md) e [capitoli/capitolo6.md](../capitoli/capitolo6.md) e [capitoli/capitolo7.md](../capitoli/capitolo7.md) e [capitoli/capitolo8.md](../capitoli/capitolo8.md) e [capitoli/capitolo9.md](../capitoli/capitolo9.md) e [capitoli/capitolo10.md](../capitoli/capitolo10.md) e [capitoli/capitolo11.md](../capitoli/capitolo11.md). Partendo da lì ottieni il quadro generale; poi approfondisci qui.

## Il tuo ambiente

| Strumento | Versione | Nota |
|---|---|---|
| Ruby | 3.1.2 | |
| Rails | 6.0.6.1 | la stessa serie del libro |
| Node | 18.19.1 | più recente di quello del libro: vedi `FIX_NODE_COMPATIBILITY.md` |
| Database | SQLite 3 | i file stanno in `db/` |

> Nel libro i comandi sono scritti come `rails ...`. Qui è usato `bin/rails ...`, che garantisce di usare la versione di Rails di **questo** progetto. Per il resto sono equivalenti.

## I passi

| # | File | Cosa si fa |
|---|---|---|
| 0 | — | `rails new blog` + fix per Node 18 (già fatto prima) |
| 1 | [01-database.md](01-database.md) | `database.yml`, ambienti, creare i database, `dbconsole` |
| 2 | [02-modello-e-migrazione.md](02-modello-e-migrazione.md) | modello `Article`, migrazione, `db:migrate`, `db:rollback` |
| 3 | [03-controller.md](03-controller.md) | generare il controller `articles` |
| 4 | [04-scaffold.md](04-scaffold.md) | annullare tutto (`destroy`) e rifarlo con lo scaffold, route REST |
| 5 | [05-nuovi-campi.md](05-nuovi-campi.md) | aggiungere `excerpt` e `location` con una migrazione |
| 6 | [06-validazioni.md](06-validazioni.md) | rendere obbligatori titolo e corpo |
| 7 | [07-file-generati.md](07-file-generati.md) | il controller e le viste spiegati riga per riga |
| 9 | [09-grafica-landing-navbar.md](09-grafica-landing-navbar.md) | **extra**: landing page, navbar, layout, partial, helper, seed, CSS: il blog "Fast Break" |
| ★ | [08-cheatsheet.md](08-cheatsheet.md) | tutti i comandi su una pagina, da tenere aperta al lavoro |

## Stato finale del progetto

```
app/models/article.rb                       ← modello con validazioni
app/controllers/articles_controller.rb      ← 7 azioni CRUD
app/views/articles/*.html.erb               ← index, show, new, edit, _form
app/views/articles/*.json.jbuilder          ← le stesse pagine in JSON
config/routes.rb                            ← resources :articles
db/migrate/..._create_articles.rb           ← crea la tabella
db/migrate/..._add_excerpt_and_location...  ← aggiunge 2 colonne
db/schema.rb                                ← fotografia attuale del DB
```

Per vederlo nel browser:

```bash
cd /home/wonderlab/blog
bin/rails server
# poi apri http://localhost:3000/articles   (Ctrl+C nel terminale per fermarlo)
```

Nel database c'è un articolo di esempio, "Beginning Rails 6".

## Glossario

| Termine | Significato |
|---|---|
| **Ambiente** | La modalità in cui gira l'app: `development`, `test` o `production`. Ognuno ha il suo database. |
| **Migrazione** | File Ruby in `db/migrate/` che descrive una modifica allo schema del DB e sa anche annullarla. |
| **Schema** | La struttura del DB: tabelle, colonne, tipi. `db/schema.rb` ne è la fotografia aggiornata. |
| **Modello** | Classe Ruby che rappresenta una tabella (`Article` ↔ `articles`). Contiene le regole sui dati. |
| **Controller** | Classe che riceve le richieste HTTP, usa i modelli e sceglie cosa rispondere. |
| **Azione** | Un metodo pubblico del controller (`index`, `show`, ...) raggiungibile da un URL. |
| **Vista** | Template (`.html.erb`) che produce l'HTML. |
| **Route** | Regola che collega URL + verbo HTTP a `controller#azione`. |
| **CRUD** | Create, Read, Update, Delete: le quattro operazioni base sui dati. |
| **REST** | Convenzione che mappa il CRUD su URL e verbi HTTP (GET, POST, PATCH, DELETE). |
| **Generatore** | Comando `bin/rails generate ...` che crea file seguendo le convenzioni. |
| **Scaffold** | Generatore che crea modello + migrazione + controller + viste + route in un colpo solo. |
| **Validazione** | Regola nel modello che impedisce di salvare dati non validi. |
| **Strong parameters** | `params.require(...).permit(...)`: lista dei campi che l'utente può inviare. |
| **CSRF** | Attacco da cui Rails protegge i form con un token nascosto (`authenticity_token`). |
