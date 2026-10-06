# Cheatsheet Rails — Capitolo 3

Tutti i comandi dell'esercizio, su una pagina. (`g` è l'abbreviazione di `generate`, `d` di `destroy`, `s` di `server`, `c` di `console`.)

## Progetto

```bash
rails new blog                      # nuova app (SQLite)
rails new blog -d postgresql        # nuova app con PostgreSQL
bin/rails s                         # server su http://localhost:3000  (Ctrl+C per fermarlo)
bin/rails c                         # console Ruby con l'app caricata
bin/rails routes -c articles        # route di un controller
bin/rails routes -g edit            # route che contengono "edit"
bin/rails test                      # esegue i test
```

## Database

```bash
bin/rails db:create                 # crea DB development + test
bin/rails db:create:all             # crea tutti i DB di database.yml
bin/rails db:migrate                # esegue le migrazioni in sospeso
bin/rails db:migrate:status         # up/down di ogni migrazione
bin/rails db:rollback               # annulla l'ultima migrazione
bin/rails db:rollback STEP=3        # annulla le ultime 3
bin/rails db:setup                  # crea DB + carica schema.rb + seeds (progetto appena clonato)
bin/rails db:seed                   # esegue db/seeds.rb
bin/rails dbconsole                 # prompt SQL del DB (.tables, .schema articles, .exit)
RAILS_ENV=test bin/rails db:migrate # un comando su un altro ambiente
```

## Generatori

```bash
bin/rails g model Article title:string body:text           # modello + migrazione + test
bin/rails g model Article --no-migration                   # solo modello
bin/rails g controller articles                            # controller + cartella viste
bin/rails g controller articles index show                 # ... con azioni e viste
bin/rails g scaffold Article title:string body:text        # tutto il CRUD
bin/rails g migration add_excerpt_to_articles excerpt:string
bin/rails g migration remove_excerpt_from_articles excerpt:string
bin/rails d <stesso comando di generate>                   # annulla un generate
```

Opzioni utili: `--no-migration`, `--force` (sovrascrive senza chiedere), `--pretend` / `-p` (mostra cosa farebbe, senza farlo).

**Ordine per annullare un modello già migrato**: prima `db:rollback`, poi `d model`.

## Migrazioni

```ruby
create_table :articles do |t|
  t.string   :title          # stringa breve
  t.text     :body           # testo lungo
  t.integer  :views
  t.boolean  :draft, default: true
  t.datetime :published_at
  t.references :user         # user_id + indice (relazioni, Capitolo 5)
  t.timestamps               # created_at, updated_at
end

add_column    :articles, :excerpt, :string
remove_column :articles, :excerpt, :string
add_index     :articles, :title
rename_column :articles, :body, :content
```

Regola d'oro: **mai modificare una migrazione già condivisa → scrivine una nuova.**

## Route REST (`resources :articles`)

| Helper | Verbo | URL | Azione |
|---|---|---|---|
| `articles_path` | GET | /articles | index |
| `articles_path` | POST | /articles | create |
| `new_article_path` | GET | /articles/new | new |
| `article_path(a)` | GET | /articles/:id | show |
| `edit_article_path(a)` | GET | /articles/:id/edit | edit |
| `article_path(a)` | PATCH/PUT | /articles/:id | update |
| `article_path(a)` | DELETE | /articles/:id | destroy |

## Convenzioni sui nomi

| Modello | Tabella | Controller | Viste |
|---|---|---|---|
| `Article` | `articles` | `ArticlesController` | `app/views/articles/` |
| `Person` | `people` | `PeopleController` | `app/views/people/` |
| `BlogImage` | `blog_images` | `BlogImagesController` | `app/views/blog_images/` |

## Schema di un controller CRUD

```ruby
before_action :set_x, only: %i[show edit update destroy]

def create
  @x = X.new(x_params)
  if @x.save
    redirect_to @x, notice: "Creato."                     # successo → redirect
  else
    render :new, status: :unprocessable_entity            # errore → render
  end
end

private
  def set_x    = @x = X.find(params[:id])                 # (sintassi Ruby 3: metodo su una riga)
  def x_params = params.require(:x).permit(:campo1, :campo2)
```

## Validazioni (nel modello)

```ruby
validates :title, :body, presence: true
validates :title, length: { maximum: 120 }
validates :email, uniqueness: true
```

Console: `a.valid?`, `a.errors.full_messages`, `a.save` (true/false), `a.save!` (eccezione).

## ERB

```erb
<% codice %>          esegue senza stampare (if, each)
<%= codice %>         esegue e stampa (con escape HTML)
<%= render 'form', article: @article %>    include _form.html.erb
<%= link_to 'Testo', article_path(a) %>
```

## Quando qualcosa non va

| Sintomo | Dove guardare |
|---|---|
| Qualsiasi errore strano | `log/development.log` o il terminale del server |
| Un campo del form non si salva | `permit` nel controller; nel log cerca `Unpermitted parameter` |
| 422 + "Can't verify CSRF token" | form scritto senza `form_with`, oppure fetch JS senza header `X-CSRF-Token` |
| `PendingMigrationError` nel browser | lancia `bin/rails db:migrate` |
| `ActiveRecord::RecordNotFound` / 404 | l'id nell'URL non esiste |
| Errore all'avvio dopo aver toccato un `.yml` | indentazione: solo spazi, niente tab |
| Modifica in `config/` non applicata | riavvia il server |
