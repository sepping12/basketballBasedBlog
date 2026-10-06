class ApplicationMailbox < ActionMailbox::Base
  # Instradamento: "se un destinatario (To, Cc…) finisce con @<dominio delle bozze>, passa l'email a DraftArticlesMailbox".
  # Le regole si leggono dall'alto in basso e vince la prima che corrisponde (come le route); :all = tutto il resto.
  # (Nel libro: /@drafts\./i. Qui il dominio è configurabile: config.x.drafts_domain.)
  routing(/@#{Regexp.escape(Rails.configuration.x.drafts_domain)}\z/i => :draft_articles)
end
