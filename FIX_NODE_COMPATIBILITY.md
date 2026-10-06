# Fix compatibilità Node – spiegazione

Ambiente: Node 18.19.1, Yarn 1.22, Ruby 3.1.2, Rails 6.0 con **Webpacker 4.3**.

## Il problema di fondo
Rails 6.0 + Webpacker 4 è uno stack del 2019-2020 (webpack 4, node-sass 4, Node 12/14). Su Node 18 si rompe in tre punti.

## Cosa ho cambiato e perché

### 1. `package.json` – aggiunto `@rails/webpacker@4.3.0`
Mancava il pacchetto npm corrispondente alla gem `webpacker`. Senza di esso non esistevano webpack, babel e i loader, quindi `bin/webpack` non poteva compilare nulla. La versione è la stessa della gem (4.3.0).

### 2. `package.json` – `resolutions`: `node-sass` → `sass` 1.69.7
`@rails/webpacker` 4.3 dipende da `node-sass@^4`, che è un modulo nativo C++ e **non compila su Node 18** (errore `gyp ERR!`). Con `resolutions` di Yarn ho sostituito `node-sass` con `sass` (Dart Sass, JavaScript puro) tramite alias `npm:sass@1.69.7`. `sass-loader` 7 usa la stessa API (`render`), quindi funziona senza cambiare codice. Ho fissato la 1.69.7 perché le versioni più recenti richiedono Node ≥ 20.

### 3. `bin/webpack` e `bin/webpack-dev-server` – `NODE_OPTIONS=--openssl-legacy-provider`
webpack 4 usa l'hash MD4, rimosso da OpenSSL 3 (Node ≥ 17). Senza il flag compare `ERR_OSSL_EVP_UNSUPPORTED`. Il flag è impostato dentro gli script `bin/`, quindi vale sia per la compilazione automatica di Rails sia per il dev server, senza export manuali.

### 4. `config/webpacker.yml` – `check_yarn_integrity: false` in development
Il controllo di Webpacker si aspettava `node-sass ^4.13`, ma ora c'è l'alias a `sass`, quindi il server si fermava con "wrong version". Il controllo è solo una verifica di sicurezza, disattivarlo è corretto con l'alias.

### 5. `package.json` – `engines: node >=18 <19`
Documenta la versione di Node testata. (`.yarnrc` ha `--ignore-engines true`, quindi non blocca l'installazione.)

## Verifica
- `yarn install` → ok
- `bin/webpack` → compila `application.js` senza errori
- `bin/rails s` → `GET /` risponde 200

## Come avviare
```bash
yarn install
bin/rails db:migrate   # se serve
bin/rails s
```

## Nota
Soluzione di compromesso per mantenere Rails 6 / Webpacker 4. A lungo termine conviene migrare a Rails 7 con importmap/jsbundling, che non ha questi problemi.
