# Passo 1 — I database del progetto

**Obiettivo**: capire dove Rails legge la configurazione del database, creare i tre database (development, test, production) e verificare che Rails ci si colleghi.

**Nel libro**: Capitolo 3, da "La prima tappa è la directory config" a "Creare il modello Article".

---

## 1.1 Orientarsi: la struttura del progetto

Il comando `rails new blog` ha creato tutte le cartelle. Per questo esercizio ne servono quattro:

| Cartella | A cosa serve |
|---|---|
| `app/` | il tuo codice: modelli (`app/models`), controller (`app/controllers`), viste (`app/views`) |
| `config/` | la configurazione: `database.yml`, `routes.rb`, ... |
| `db/` | i file SQLite, le migrazioni (`db/migrate/`) e `schema.rb` |
| `log/` | se qualcosa va storto, la spiegazione di solito è in `log/development.log` |

**Per il lavoro**: **ogni** progetto Rails ha questa struttura. Quando entri in un progetto nuovo, sai già dove cercare. È il vantaggio della *convention over configuration*.

## 1.2 Leggere `config/database.yml`

[config/database.yml](../config/database.yml), senza commenti:

```yaml
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  <<: *default
  database: db/development.sqlite3

test:
  <<: *default
  database: db/test.sqlite3

production:
  <<: *default
  database: db/production.sqlite3
```

| Riga | Significato |
|---|---|
| `default: &default` | Blocco di impostazioni comuni. `&default` è un'**àncora** YAML: un'etichetta che permette di riusarlo. |
| `adapter: sqlite3` | Tipo di database. Con PostgreSQL sarebbe `postgresql`, con MySQL `mysql2`. |
| `pool: <%= ... %>` | Numero massimo di connessioni aperte insieme. `<%= %>` è codice Ruby dentro il YAML: legge la variabile d'ambiente `RAILS_MAX_THREADS` e, se manca, usa 5. |
| `timeout: 5000` | Millisecondi di attesa se il DB è occupato. |
| `<<: *default` | "Copia qui tutto il contenuto di `default`". Evita di ripetere le stesse righe tre volte. |
| `database: ...` | Il file (o il nome) del database di quell'ambiente. |

**Perché tre database?** I test cancellano e ricreano i dati a ogni esecuzione: se usassero il DB di sviluppo, perderesti quello che hai inserito. E i dati veri degli utenti (production) non devono mai mescolarsi con le prove.

Senza indicazioni, `bin/rails server`, `bin/rails console` e `bin/rails db:migrate` usano **development**. Per un altro ambiente: `RAILS_ENV=test bin/rails db:migrate`.

> ⚠️ **YAML e gli spazi**: in YAML l'indentazione ha un significato. Usa solo spazi, mai tab. Se Rails dà un errore strano all'avvio dopo che hai toccato un `.yml`, controlla per prima cosa l'indentazione.

## 1.3 Creare i database

```bash
bin/rails db:create
```

Output reale:

```
Database 'db/development.sqlite3' already exists
Created database 'db/test.sqlite3'
```

In development, `db:create` crea il DB di development **e** quello di test. Il file di development esisteva già, perché era stato creato al primo avvio del server: "already exists" è solo un'informazione, non un errore.

```bash
bin/rails db:create:all
```

```
Database 'db/development.sqlite3' already exists
Database 'db/test.sqlite3' already exists
Created database 'db/production.sqlite3'
```

`:all` significa "tutti gli ambienti elencati in `database.yml`".

```bash
ls db/
# development.sqlite3  production.sqlite3  seeds.rb  test.sqlite3
```

> Con SQLite il database è un semplice file, quindi `db:create` non sarebbe indispensabile. Con PostgreSQL/MySQL invece è obbligatorio, ed è lì che vedresti errori come "Access denied for user". In quel caso vanno controllati username e password in `database.yml`.

## 1.4 Entrare nel database con `dbconsole`

```bash
bin/rails dbconsole
```

Si apre il prompt `sqlite>`. Rails ha letto `database.yml` e ti ha collegato al DB giusto, senza che tu scrivessi il percorso.

```
sqlite> .databases
main: /home/wonderlab/blog/db/development.sqlite3 r/w
sqlite> .tables
sqlite> .exit
```

- `.databases`: a quale file sei collegato (`r/w` = lettura e scrittura).
- `.tables`: elenco delle tabelle (per ora vuoto).
- `.exit`: esci.

I comandi col punto sono comandi di SQLite. Il SQL vero e proprio (`SELECT * FROM articles;`, con il `;` finale) si scrive nello stesso prompt.

**Per il lavoro**: `bin/rails dbconsole` funziona uguale con PostgreSQL (apre `psql`) e MySQL (apre `mysql`). È il modo più veloce per guardare i dati grezzi senza installare strumenti grafici.

## 1.5 Verificare la connessione

```bash
bin/rails db:migrate
```

Output: **nessuno**. Non ci sono ancora migrazioni da eseguire, quindi non succede niente. Nessun errore significa che Rails si collega al database.

---

## 🧠 Domande di verifica

1. Se lanci `bin/rails server` senza opzioni, quale database usa l'app?
2. Cosa significa `<<: *default` in `database.yml`?
3. Perché "already exists" non è un problema?
4. Perché `db:migrate`, a questo punto, non stampa niente?

<details><summary>Risposte</summary>

1. `db/development.sqlite3`: l'ambiente predefinito è development.
2. Copia nel blocco corrente tutte le chiavi del blocco con àncora `&default`.
3. Rails ti dice solo che il database c'era già e che non l'ha toccato.
4. In `db/migrate/` non c'è ancora nessuna migrazione da eseguire.

</details>
