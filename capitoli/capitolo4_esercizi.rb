# Capitolo 4 — Introduzione al linguaggio Ruby: tutti gli esempi del capitolo.
#
# Esegui con:   ruby capitoli/capitolo4_esercizi.rb
#
# Per le espressioni brevi uso irb("codice"): esegue il codice e stampa il
# risultato come farebbe irb (riga "=>"). Le variabili restano disponibili tra
# una chiamata e l'altra, esattamente come in una sessione irb.

def sezione(titolo)
  puts
  puts "=" * 64
  puts titolo
  puts "=" * 64
end

def irb(codice)
  puts "irb> #{codice}"
  risultato = eval(codice, TOPLEVEL_BINDING)
  puts "=> #{risultato.inspect}"
rescue StandardError, ScriptError => e
  puts "!! #{e.class}: #{e.message}"
end

# ---------------------------------------------------------------------------
sezione "INTERAZIONE ISTANTANEA (irb)"
irb '"Hello, World!"'
irb "1 + 1"
irb "Time.now.year"
irb "Time.now.class"

# ---------------------------------------------------------------------------
sezione "TIPI DI DATO — Stringhe"
irb "'Ruby is a great language'"
irb '"Rails is a great framework"'
irb '"Now is #{Time.now.year}"'    # apici doppi: interpolazione
irb "'Now is \#{Time.now.year}'"   # apici singoli: nessuna interpolazione
irb '"Toronto - Canada".downcase'
irb '"New York, USA".upcase'
irb '"a " + "few " + "strings " + "together"'
irb '"HELLO".capitalize'
irb '"a string".methods.grep(/case/).sort'

sezione "TIPI DI DATO — Numeri"
irb "1 + 2"
irb "9093 - 23236"
irb "343 / 4564"           # interi: il risultato è intero (0!)
irb "99 * 345"
irb "34545.6 / 3434.1"
irb "6 / 4"                # divisione tra interi
irb "6 / 4.0"              # basta un decimale: risultato decimale
irb "2 + 3"
irb '"2" + "3"'            # tra virgolette: stringhe, si concatenano
irb "7 % 3"                # resto
irb "2 ** 10"              # potenza
irb "5.class"
irb "5.5.class"

sezione "TIPI DI DATO — Simboli"
irb ":my_symbol"
irb ":my_symbol + :second" # errore: i simboli non si possono "sommare"
irb '"my_string" + "second"'
irb ":a.object_id == :a.object_id"       # stesso simbolo = stesso oggetto
irb '"a".object_id == "a".object_id'     # due stringhe uguali = oggetti diversi

sezione "TIPI DI DATO — Array"
irb "city_array = ['Toronto', 'Miami', 'Paris']"
irb "city_array[0]"
irb "city_array[1] = 'New York'"
irb "city_array << 'London'"
irb 'city_array + ["Los Angeles"]'   # restituisce un NUOVO array
irb "city_array"                     # city_array non è stato modificato da +
irb "city_array.first"
irb "city_array.last"
irb "city_array.size"
irb "numbers_array = [1, 2, 3, 4, 5]"

sezione "TIPI DI DATO — Hash"
irb "my_hash = {canada: 'Toronto', france: 'Paris', uk: 'London'}"
irb "my_hash[:uk]"
irb "my_hash[:canada] = 'Calgary'"
irb "my_hash.first"
irb "my_hash.keys"
irb "my_hash.values"
irb "numbers_hash = {one: 1, two: 2, three: 3}"
irb '{"uno" => 1, 2 => "due"}'       # stile Hashrocket: chiavi di qualsiasi tipo

# ---------------------------------------------------------------------------
sezione "BASI — Variabili"
irb "test_variable = 'This is a string'"
irb "test_variable = 2010"
irb "test_variable = 232.3"
irb "test_variable.class"

class Contatore
  SERVER_IP = "127.0.0.1"          # costante
  @@totale = 0                      # variabile di CLASSE: condivisa da tutte le istanze

  def initialize(nome)
    @nome = nome                    # variabile di ISTANZA: una per ogni oggetto
    @@totale += 1
  end

  def descrivi
    prefisso = "Contatore"          # variabile LOCALE: vive solo dentro il metodo
    "#{prefisso} #{@nome} (totale creati: #{@@totale})"
  end
end

a = Contatore.new("A")
b = Contatore.new("B")
puts a.descrivi
puts b.descrivi
puts "Costante: #{Contatore::SERVER_IP}"
$utente = "giuseppe"                # variabile GLOBALE (da evitare)
puts "Globale: #{$utente}"

sezione "BASI — Operatori"
irb "10 > 5 && 3 > 1"
irb "10 > 5 || 3 > 100"
irb "!(1 == 2)"
irb "(1..5).to_a"                  # intervallo con estremo incluso
irb "(1...5).to_a"                 # intervallo con estremo escluso
irb "6 & 3"                        # AND bit a bit
irb "6 ^ 3"                        # OR esclusivo
irb "6 | 3"                        # OR bit a bit
irb "a = 10"
irb "b = 20"
irb "a > b ? a : b"                # operatore ternario

sezione "BASI — Blocchi e iteratori"
puts "5.times { puts \"Hello\" }"
5.times { puts "Hello" }
puts
puts "[1,2,3,4,5].each { |item| puts item }"
[1, 2, 3, 4, 5].each { |item| puts item }
puts
puts "each_with_index:"
["a", "b", "c"].each_with_index do |item, index|
  puts "Item: #{item}"
  puts "Index: #{index}"
  puts "---"
end
irb "[1, 2, 3].map { |n| n * 2 }"           # trasforma ogni elemento
irb "[1, 2, 3, 4].select { |n| n.even? }"   # tiene solo quelli che soddisfano

sezione "BASI — Strutture di controllo"
now = Time.now
if now == Time.now
  puts "now is in the past"
elsif now > Time.now
  puts "nonsense"
else
  puts "time has passed"
end

x = 5
y = 10
puts "b is greater than a" if x < y                 # modificatore if
puts "a is greater than b" unless x < y             # modificatore unless (non stampa)
puts "(nessuna riga sopra per 'unless': x < y è vero)"
while x < y
  puts "a is #{x}"
  x += 1
end

sezione "BASI — Metodi"
def time_as_string
  Time.now.to_s
end
puts time_as_string.class

def say_hello_to(name)
  "Hello, #{name}!"
end
puts say_hello_to("John")

# ---------------------------------------------------------------------------
sezione "CLASSI E OGGETTI — Approccio procedurale (quello da NON preferire)"
rowing_team = [[1975, "Smith", "John"], [1964, "Brown", "Dan"]]
puts "Primo studente: #{rowing_team.first.inspect}"
teams = { rowing: rowing_team, track: [[1975, "Smith", "John"], [1900, "Mark", "Twain"]] }
puts "Squadre: #{teams.keys.inspect}"
puts "...ma chi è l'elemento [0] di ogni array? Matricola? Cognome? Non si capisce."

sezione "CLASSI E OGGETTI — Student con getter/setter scritti a mano"
class StudentManuale
  def first_name=(value)
    @first_name = value
  end

  def first_name
    @first_name
  end

  def last_name=(value)
    @last_name = value
  end

  def last_name
    @last_name
  end

  def full_name
    last_name + ", " + first_name
  end
end
@student = StudentManuale.new
@student.first_name = "Bob"
@student.last_name = "Jones"
puts @student.full_name

sezione "CLASSI E OGGETTI — Student con attr_accessor, e Team"
class Student
  attr_accessor :first_name, :last_name, :id_number   # genera getter + setter

  def full_name
    last_name + ", " + first_name
  end
end

class Team
  attr_accessor :name, :students

  def initialize(name)
    @name = name
    @students = []
  end

  def add_student(id_number, first_name, last_name)
    student = Student.new
    student.id_number = id_number
    student.first_name = first_name
    student.last_name = last_name
    @students << student
  end

  def print_students
    @students.each do |student|
      puts student.full_name
    end
  end
end

team = Team.new("Rowing")
team.add_student(1982, "John", "Smith")
team.add_student(1984, "Bob", "Jones")
team.print_students
puts "Squadra: #{team.name}, studenti: #{team.students.size}"

sezione "CLASSI E OGGETTI — Ispezionare un oggetto"
irb "Student.instance_methods(false).sort"
irb "team.students.first.id_number"
irb "team.students.map(&:full_name)"
irb "Student.new.respond_to?(:full_name)"
