class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Se nel frattempo il record passato al job è stato eliminato (es. l'articolo), il job non ha più senso: si scarta.
  discard_on ActiveJob::DeserializationError
end
