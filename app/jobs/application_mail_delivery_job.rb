# Il job che consegna le email di deliver_later. Di default Rails usa ActionMailer::MailDeliveryJob, che NON eredita
# da ApplicationJob: quindi non ha il `discard_on` di ApplicationJob. Qui lo si rimette: se l'articolo o il commento
# passato all'email è stato eliminato prima dell'invio, l'email non ha più senso e il job si scarta in silenzio.
class ApplicationMailDeliveryJob < ActionMailer::MailDeliveryJob
  discard_on ActiveJob::DeserializationError
end
