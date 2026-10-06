class ApplicationMailer < ActionMailer::Base
  # Il mittente: cambialo con lo STESSO indirizzo dell'account SMTP (altrimenti molti provider scartano le email).
  self.delivery_job = ApplicationMailDeliveryJob     # Capitolo 13: il job di deliver_later (vedi app/jobs)
  default from: "Fast Break <blog@example.com>"
  layout "mailer"
end
