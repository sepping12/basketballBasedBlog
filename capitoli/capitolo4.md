# Capitolo 4 — Introduzione al linguaggio Ruby

> **In una frase**: Rails è scritto in Ruby e il codice che scrivi è Ruby. Questo capitolo ti dà il linguaggio, con gli esempi da provare in `irb`.

## 1. Il contesto (perché serve)

Nel Capitolo 3 hai usato Rails senza sapere bene cosa fosse "Ruby" e cosa fosse "Rails". Quasi tutto il codice del blog è Ruby normale. Ecco dove hai **già** incontrato ogni concetto di questo capitolo:

| Concetto Ruby | Dove lo trovi nel blog |
|---|---|
| **Classe** e ereditarietà | `class Article < ApplicationRecord` |
| **Simbolo** (`:nome`) | `validates :title, :body ...`, `before_action :set_article` |
| **Hash** | `presence: true`, `notice: "..."`, `params[:id]` |
| **Array** | `%i[show edit update destroy]`, `MESI[time.month - 1]` |
| **Blocco / iteratore** | `@articles.each do \|article\| ... end` nelle viste |
| **Interpolazione** `#{}` | `"#{time.day} #{MESI[...]} #{time.year}"` |
| **Metodo** con argomenti | `def nav_link(text, path, match: nil)` |
| **Variabile di istanza** `@` | `@article`, `@articles`: il controller le passa alla vista |
| **Concatenazione di metodi** | `params.require(:article).permit(:title, :body)` |
| **Costante** | `MESI = %w[gennaio febbraio ...]` |
| **`if` / `unless`** | `<% if notice.present? %>`, `<% if article.errors.any? %>` |

Quando leggi un file Rails e non capisci una riga, quasi sempre la risposta è in una di queste righe.

## 2. Cosa ho fatto

Ho eseguito **tutti gli esempi del capitolo** in uno script: [capitolo4_esercizi.rb](capitolo4_esercizi.rb). Il suo output è identico a quello del libro.

```bash
ruby capitoli/capitolo4_esercizi.rb       # lancia tutti gli esempi
irb                                       # per provare a mano (exit per uscire)
```

Lo script stampa come `irb`: `irb> codice` e `=> risultato`. Puoi aprirlo e modificare gli esempi.

## 3. I concetti, con il risultato vero

### Tipi di dato

| Tipo | Esempio | Risultato / nota |
|---|---|---|
| **String** | `"Toronto".downcase` | `"toronto"`; `upcase`, `capitalize` |
| Interpolazione | `"Now is #{Time.now.year}"` | `"Now is 2026"`: solo con **apici doppi** |
| Apici singoli | `'Now is #{Time.now.year}'` | niente interpolazione: resta testo |
| **Integer** | `343 / 4564` | `0`: tra interi il risultato è intero! |
| **Float** | `6 / 4.0` | `1.5`: basta un decimale |
| Numeri come testo | `"2" + "3"` | `"23"`: tra virgolette sono stringhe |
| **Symbol** | `:my_symbol + :second` | **errore** `NoMethodError`: i simboli non si modificano |
| **Array** | `city_array[0]` | `"Toronto"`: gli indici partono da **0** |
| Aggiungere | `city_array << 'London'` | modifica l'array |
| Sommare | `city_array + ["Los Angeles"]` | crea un **nuovo** array, l'originale non cambia |
| **Hash** | `my_hash[:uk]` | `"London"`: valore per chiave |
| `.first`, `.keys` | `my_hash.first` | `[:canada, "Calgary"]` / `[:canada, :france, :uk]` |

**Simbolo vs stringa**: un simbolo (`:title`) è un'etichetta fissa che non si modifica. Due simboli uguali sono lo stesso oggetto, due stringhe uguali no (`:a.object_id == :a.object_id` → `true`, `"a".object_id == "a".object_id` → `false`). Per questo Rails li usa come nomi di campi e chiavi di hash.

**Stile hash**: `{canada: 'Toronto'}` (moderno, solo chiavi-simbolo) e `{:canada => 'Toronto'}` (Hashrocket, qualsiasi chiave) sono equivalenti. Ruby 3.1 li mostra nel secondo stile.

**Trucco per esplorare**: `"a string".methods.grep(/case/)` elenca i metodi di un oggetto che contengono "case" (→ `upcase`, `downcase`, `swapcase`...). Funziona su qualsiasi oggetto.

### Variabili: il primo carattere decide il tipo

| Esempio | Tipo | Durata |
|---|---|---|
| `my_string` | **locale** | solo nel metodo/blocco dove è creata |
| `@name` | **di istanza** | una per ogni oggetto; visibile in tutti i suoi metodi (e nelle viste, se è nel controller) |
| `@@count` | **di classe** | una sola, condivisa da tutti gli oggetti della classe |
| `SERVER_IP` | **costante** | non dovrebbe cambiare |
| `$user` | **globale** | ovunque: **da evitare** |

Nello script: creando due `Contatore`, `@@totale` vale 2 per entrambi (condivisa), mentre `@nome` è diverso per ciascuno. In Ruby non si dichiara il tipo e si può riassegnare: `x = 'testo'; x = 2010; x = 232.3`.

**Convenzione**: nomi lunghi e descrittivi (`place_holder_variable`, non `phi`), in `snake_case`.

### Operatori

| Operatori | Esempio | Risultato |
|---|---|---|
| Aritmetici `+ - * / % **` | `7 % 3`, `2 ** 10` | `1`, `1024` |
| Confronto `< > <= >= ==` | `10 > 5` | `true` |
| Logici `&& \|\| !` | `10 > 5 && 3 > 1` | `true` |
| Intervalli `..` e `...` | `(1..5).to_a` / `(1...5).to_a` | `[1,2,3,4,5]` / `[1,2,3,4]` |
| **Ternario** `cond ? a : b` | `a > b ? a : b` | un `if/else` su una riga |

### Blocchi e iteratori

Un **blocco** è un pezzo di codice passato a un metodo, tra `{ }` (una riga) o `do ... end` (più righe). Gli argomenti del blocco stanno tra `| |`.

```ruby
5.times { puts "Hello" }                       # stampa Hello 5 volte
[1, 2, 3].each { |item| puts item }            # stampa 1, 2, 3
["a", "b"].each_with_index do |item, index|    # elemento + indice
  puts "#{index}: #{item}"
end
[1, 2, 3].map { |n| n * 2 }                    # => [2, 4, 6]   trasforma
[1, 2, 3, 4].select { |n| n.even? }            # => [2, 4]      filtra
```

È il concetto più usato in Rails: ogni `@articles.each do |article|` nelle viste è un blocco.

### Strutture di controllo

```ruby
if x == 1 ... elsif x > 1 ... else ... end     # finiscono sempre con "end"
puts "ok" if a < b                             # modificatore: if a fine riga
puts "no" unless a < b                         # unless = "se NON"
while a < b
  a += 1
end
```

### Metodi

```ruby
def say_hello_to(name)
  "Hello, #{name}!"      # l'ULTIMA espressione è il valore restituito (niente "return")
end
```

### Classi e oggetti

Una **classe** è lo stampo, un **oggetto** (istanza) è ciò che esce dallo stampo con `new`.

```ruby
class Student
  attr_accessor :first_name, :last_name, :id_number   # crea getter + setter da soli

  def full_name
    last_name + ", " + first_name
  end
end
```

- `attr_accessor :first_name` equivale a scrivere a mano `def first_name; @first_name; end` e `def first_name=(v); @first_name = v; end`. Nello script ho fatto **entrambe** le versioni, con lo stesso risultato (`Jones, Bob`).
- `initialize` è il metodo chiamato da `new`: `Team.new("Rowing")` lo esegue con `"Rowing"`.
- Una `Team` contiene un array di `Student`: oggetti che contengono oggetti. Molto più chiaro del metodo "procedurale" con array di array, dove `[1975, "Smith", "John"]` non dice cosa sia il `1975`.

Risultato dello script: `team.print_students` stampa `Smith, John` e `Jones, Bob`.

**Perché conta per Rails**: `Article` è una classe, `Article.new` crea un oggetto, `@article.title` e `@article.title = "..."` sono getter e setter. Active Record ti dà i `attr_accessor` per ogni colonna della tabella, automaticamente.

## 4. Errori e trappole (le più frequenti per chi comincia)

| Trappola | Cosa succede | Rimedio |
|---|---|---|
| `6 / 4` | `1`, non `1.5` | scrivi `6 / 4.0` o `6.0 / 4` |
| `"2" + "3"` | `"23"` | stringhe si concatenano; per sommare usa i numeri |
| `:a + :b` | `NoMethodError` | i simboli sono immutabili |
| `'Ciao #{nome}'` | stampa `#{nome}` letterale | usa apici **doppi** |
| `array + [x]` | non modifica `array` | usa `<<` o `push` per modificare |
| `puts "..." unless a < b` | in irb mostra `nil` | è normale: `puts` restituisce `nil` |
| Indice array | il primo è `[0]`, non `[1]` | |

## 5. Stile Ruby

Indentazione di **2 spazi** (mai tab), `snake_case` per variabili e metodi, `CamelCase` per le classi, parentesi nelle chiamate con argomenti, nomi descrittivi. L'importante è la coerenza.

## 6. Documentazione

- Classi e metodi base: <https://ruby-doc.org/core/>
- Libreria standard: <https://ruby-doc.org/stdlib/>

Se in terminale hai `ri`, `ri String#upcase` mostra la documentazione di un metodo.

## 7. Checklist del capitolo

- [x] irb: espressioni, `Time.now`, risultato `=>`
- [x] Stringhe, interpolazione, metodi (`upcase`, `capitalize`...)
- [x] Numeri: interi vs decimali
- [x] Simboli e immutabilità
- [x] Array (`[]`, `<<`, `+`) e hash (`[]`, `first`, `keys`)
- [x] Variabili: globali, di classe, di istanza, costanti, locali
- [x] Operatori, ternario, intervalli
- [x] Blocchi e iteratori (`times`, `each`, `each_with_index`)
- [x] `if`/`elsif`/`else`, `unless`, `while`
- [x] Metodi con argomenti
- [x] Classi: `attr_accessor`, `initialize`, `Student` e `Team`

## 8. Auto-verifica

1. Che cosa restituisce `7 / 2` e come ottieni `3.5`?
2. Cosa cambia tra `array << x` e `array + [x]`?
3. Perché in `validates :title, presence: true` compaiono un simbolo e un hash?
4. Cosa fa `@articles.each do |article| ... end`?
5. Perché `@article` in un controller è visibile nella vista, ma `article` locale no?

<details><summary>Risposte</summary>

1. `3`; scrivi `7 / 2.0` (o `7.0 / 2`).
2. `<<` modifica l'array originale; `+` ne crea uno nuovo.
3. `:title` è un simbolo (il nome del campo), `presence: true` è un hash (`{presence: true}`) senza graffe.
4. Ripete il blocco per ogni elemento, passandolo come `article`.
5. Le variabili di istanza (`@`) appartengono all'oggetto controller, e Rails le copia nella vista. Le locali vivono solo nel metodo.

</details>
