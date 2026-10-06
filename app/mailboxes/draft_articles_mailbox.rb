# Riceve le email indirizzate a <token>@drafts… e le trasforma in BOZZE di articoli:
# oggetto → titolo, testo → testo dell'articolo. L'autore è l'utente che possiede quel token.
class DraftArticlesMailbox < ApplicationMailbox
  # Come i filtri dei controller: prima di elaborare, controlla che l'indirizzo corrisponda a un utente.
  before_processing :require_author

  def process
    articolo = author.articles.new(title: mail.subject.to_s.strip.first(200), body: PlainText.to_html(testo_del_messaggio))
    # Nessun published_at: è una BOZZA (visibile solo all'autore).

    if articolo.save
      DraftArticlesMailer.created(mail.from, articolo).deliver_later          # conferma, con il link per modificarla
    else
      # Il libro usa create!: se manca l'oggetto l'eccezione fa fallire l'elaborazione. Qui si risponde al mittente.
      bounce_with DraftArticlesMailer.invalid_draft(mail.from, articolo.errors.full_messages)
    end
  end

  private

  # bounce_with: segna l'email come "bounced" (rimbalzata), spedisce la risposta e FERMA l'elaborazione.
  def require_author
    bounce_with DraftArticlesMailer.no_author(mail.from) unless author
  end

  # `@author ||= …` (memoization): la query gira una volta sola, anche se `author` si usa più volte.
  def author
    @author ||= User.find_by(draft_article_token: token)
  end

  # Il token è la parte prima della @ del PRIMO destinatario che finisce col dominio delle bozze.
  def token
    indirizzo = mail.recipients.find { |a| a.to_s.downcase.end_with?("@#{Rails.configuration.x.drafts_domain}") }
    indirizzo.to_s.split("@").first
  end

  # Il testo semplice dell'email. Se è multipart si preferisce la parte "text/plain"; se c'è solo HTML se ne tolgono i tag.
  def testo_del_messaggio
    if mail.multipart?
      return mail.text_part.decoded.to_s if mail.text_part
      return ActionController::Base.helpers.strip_tags(mail.html_part.decoded.to_s) if mail.html_part
      ""
    elsif mail.mime_type.to_s == "text/html"
      ActionController::Base.helpers.strip_tags(mail.decoded.to_s)
    else
      mail.decoded.to_s
    end
  end
end
