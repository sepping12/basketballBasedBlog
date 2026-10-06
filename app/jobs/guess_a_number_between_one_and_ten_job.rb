# Job "didattico" del Capitolo 13: indovina un numero tra 1 e 10.
# Non serve al blog: mostra queue_as, perform, perform_later, retry_on e discard_on.
class GuessANumberBetweenOneAndTenJob < ApplicationJob
  queue_as :default                      # la coda (se ne possono avere di diverse, es. :critical)

  # Eccezioni personalizzate: una classe vuota che eredita da StandardError, su una riga.
  class ThatsNotFair < StandardError; end
  class GuessedWrongNumber < StandardError; end

  discard_on ThatsNotFair                                # numero non valido → il job si SCARTA (inutile riprovare)
  retry_on GuessedWrongNumber, attempts: 8, wait: 1      # numero sbagliato → si RIPROVA (max 8 volte, ogni 1 s)

  # perform è obbligatorio: è ciò che il job fa quando viene eseguito. Può ricevere argomenti.
  def perform(my_number)
    unless my_number.is_a?(Integer) && my_number.between?(1, 10)
      raise ThatsNotFair, "#{my_number} non è un intero tra 1 e 10!"
    end

    guessed_number = rand(1..10)
    if guessed_number == my_number
      Rails.logger.info "Indovinato! Era #{my_number}"
    else
      raise GuessedWrongNumber, "È il #{guessed_number}? No? Mmm."
    end
  end
end
