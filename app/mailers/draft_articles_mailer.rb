# Le risposte alle email di bozze: errore (nessun utente / bozza non valida) e conferma.
class DraftArticlesMailer < ApplicationMailer
  # Contenuto "inline" con un blocco format (come nel libro): niente file di template per un messaggio semplice.
  def no_author(to)
    mail to: to, subject: "Non è stato possibile elaborare la tua email" do |format|
      contenuto = "Controlla l'indirizzo per le bozze (lo trovi nella pagina «Scrivi») e riprova."
      format.html { render plain: contenuto }
      format.text { render plain: contenuto }
    end
  end

  def invalid_draft(to, errori)
    mail to: to, subject: "La bozza non è stata creata" do |format|
      contenuto = "La bozza non è stata creata: #{Array(errori).to_sentence(two_words_connector: " e ", last_word_connector: " e ")}. Scrivi un oggetto e un testo e riprova."
      format.html { render plain: contenuto }
      format.text { render plain: contenuto }
    end
  end

  def created(to, article)
    @article = article
    mail to: to, subject: "La tua bozza è stata creata"
  end
end
