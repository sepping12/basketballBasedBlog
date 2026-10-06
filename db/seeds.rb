# Dati di esempio per il blog. Sono TESTI DI PROVA: riscrivili a modo tuo
# (oppure cancellali da /articles). Si carica con:  bin/rails db:seed
# È sicuro rilanciarlo: ciò che esiste già non viene duplicato né sovrascritto.
# (Il libro usa db:setup per questo; find_or_create_by! evita il problema.)

# Utente di prova (Capitolo 6). NON usare questa password su un sito vero.
user = User.find_or_create_by!(email: 'mary@example.com') do |u|
  u.password = 'guessit'
  u.password_confirmation = 'guessit'
end

# Le 5 categorie sono i temi del "quintetto" della landing page.
%w[NBA Serie\ A Tattica Allenamento Storia].each do |name|
  Category.find_or_create_by!(name: name)
end

articles = [
  {
    title: "Perché il pick and roll non passa mai di moda",
    categories: %w[Tattica],
    location: "Milano",
    excerpt: "Un blocco, un taglio, una scelta: la giocata più semplice è ancora la più difficile da difendere.",
    published_at: Time.zone.local(2026, 10, 4, 18, 30),
    body: <<~TEXT
      Il pick and roll nasce da un'idea semplicissima: un giocatore con la palla e un compagno che gli porta un blocco. Eppure, dopo decenni, resta l'azione più usata a ogni livello, dal campetto alla finale.

      Il motivo è che costringe la difesa a decidere. Chi marca il palleggiatore può passare dietro il blocco, cambiare, o raddoppiare. Ogni scelta lascia scoperto qualcosa: un tiro da fuori, un taglio verso il ferro, un passaggio all'angolo.

      Per attaccarlo bene servono tre cose: un blocco vero (con i piedi fermi), un palleggiatore che legge prima di muoversi e un compagno che sa quando aprirsi e quando tagliare.

      La prossima volta che guardi una partita prova a ignorare la palla per qualche possesso. Guarda solo cosa fanno i difensori quando arriva il blocco: capirai quasi tutto della partita.
    TEXT
  },
  {
    title: "Tre fondamentali da allenare ogni settimana",
    categories: %w[Allenamento],
    location: "Bologna",
    excerpt: "Non serve un'ora di allenamento: bastano pochi minuti ben fatti, sempre sugli stessi gesti.",
    published_at: Time.zone.local(2026, 10, 1, 9, 0),
    body: <<~TEXT
      Quando si comincia a giocare si tende a copiare le giocate spettacolari. Ma sono i fondamentali a fare la differenza, e si allenano anche da soli, con un pallone e mezzo campo.

      Primo: il palleggio con la mano debole. Dieci minuti di palleggio in movimento, solo con la mano sbagliata, cambiano il modo in cui leggi il campo.

      Secondo: il tiro da fermo. Cinque posizioni attorno all'area, dieci tiri ciascuna, con la stessa routine ogni volta. La ripetizione costruisce la fiducia.

      Terzo: i passi. Arresti, perni, partenze: sono la base di ogni movimento. Lavorarci prima di tirare ti evita di buttare via possessi per una banale infrazione.
    TEXT
  },
  {
    title: "Il tiro da tre punti ha cambiato tutto",
    categories: %w[Storia Tattica],
    location: "Roma",
    excerpt: "Una linea sul parquet ha riscritto il modo di giocare: breve storia di un'idea rivoluzionaria.",
    published_at: Time.zone.local(2026, 9, 26, 20, 15),
    body: <<~TEXT
      Oggi sembra normale, ma il tiro da tre punti è relativamente giovane. È stato sperimentato negli anni Sessanta nella lega americana ABA, ed è entrato nella NBA nella stagione 1979-80. La FIBA lo ha adottato a metà degli anni Ottanta.

      All'inizio era visto quasi come una curiosità: un tiro rischioso, da usare quando non c'era di meglio. Col tempo le squadre hanno fatto i conti: un tiro da tre al 36% vale quanto uno da due al 54%.

      Il risultato è sotto gli occhi di tutti: spaziature più larghe, lunghi che tirano da fuori, attacchi costruiti per liberare l'angolo. Non tutti lo considerano un miglioramento, ma è innegabile che il gioco sia diventato un altro.
    TEXT
  },
  {
    title: "L'ultimo quarto: come si legge una partita punto a punto",
    categories: %w[Tattica],
    location: "Torino",
    excerpt: "Quando il tabellone dice parità e il tempo scorre, contano le piccole cose.",
    published_at: Time.zone.local(2026, 9, 20, 21, 0),
    body: <<~TEXT
      Gli ultimi cinque minuti di una partita in equilibrio hanno una loro grammatica. Il ritmo scende, i possessi diventano preziosi, ogni palla persa pesa il doppio.

      Le squadre migliori non cambiano identità: fanno meglio quello che sanno fare. Chi ha un playmaker affidabile gli consegna la palla, chi ha un grande difensore lo mette sul migliore avversario.

      Poi ci sono i dettagli: chi prende il rimbalzo offensivo, chi chiude bene sul tiratore, chi ha il coraggio di prendersi l'ultimo tiro anche dopo averne sbagliati tre. È lì che una partita si decide, e che il basket diventa bellissimo.
    TEXT
  }
]

articles.each do |attrs|
  article = Article.find_or_create_by!(title: attrs[:title]) do |a|
    a.assign_attributes(attrs.except(:categories))
  end
  article.update!(user: user) if article.user.nil?
  article.categories = Category.where(name: attrs[:categories]) if article.categories.empty?
end

puts "Utenti: #{User.count} - Categorie: #{Category.count} - Articoli: #{Article.count}"
