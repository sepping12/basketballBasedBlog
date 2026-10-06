class ApplicationMailer < ActionMailer::Base
  # Il mittente: cambialo con lo STESSO indirizzo dell'account SMTP (altrimenti molti provider scartano le email).
  default from: "Fast Break <blog@example.com>"
  layout "mailer"
end
