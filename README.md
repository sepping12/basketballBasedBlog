# Fast Break 🏀

Un blog di basket scritto con **Ruby on Rails 6**, nato come esercizio dei capitoli 3 e 4 di *Beginning Rails 6* e poi ampliato: landing page, navbar, articoli, tema arancione e nero.

## Cosa c'è

- Landing page con hero, "quintetto" dei temi e ultimi articoli
- CRUD degli articoli (titolo, luogo, estratto, testo, data) con validazioni in italiano
- Navbar responsive (menu a hamburger su telefono) e footer
- Tutto in CSS puro e SVG, senza immagini esterne
- Articoli di esempio in `db/seeds.rb`
- Test per modello e pagine (`bin/rails test`)

## Requisiti

- Ruby 3.1.2
- Node 18 e Yarn 1.x (vedi [FIX_NODE_COMPATIBILITY.md](FIX_NODE_COMPATIBILITY.md))
- SQLite 3

## Avvio

```bash
bundle install
yarn install
bin/rails db:setup     # crea il database, carica lo schema e gli articoli di esempio
bin/rails server       # http://localhost:3000
```

Test: `bin/rails test`

## Guida di studio

La cartella [guida/](guida/) contiene una guida in italiano, passo per passo, con comandi, output reali e spiegazioni: database, modelli e migrazioni, controller, scaffold, validazioni, e la parte di grafica. Si parte da [guida/README.md](guida/README.md).

## ⚠️ Nota

Non c'è autenticazione: chiunque può creare, modificare ed eliminare articoli. Va bene in locale, non su un sito pubblico.
