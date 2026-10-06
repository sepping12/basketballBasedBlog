class NotifierMailer < ApplicationMailer
  # "Invia a un amico": un lettore consiglia un articolo a qualcuno.
  def email_friend(article, sender_name, receiver_email)
    @article = article
    @sender_name = sender_name

    # Allegato dinamico: la copertina dell'articolo (se c'è). `download` è un metodo di Active Storage.
    if article.cover_image.attached?
      attachments[article.cover_image.filename.to_s] = article.cover_image.download
    end

    mail to: receiver_email, subject: "#{sender_name} ti consiglia un articolo: #{article.title}"
  end

  # Avviso all'autore di un articolo quando riceve un commento (lo chiama il callback di Comment).
  def comment_added(comment)
    @comment = comment
    @article = comment.article

    mail to: @article.user.email, subject: "Nuovo commento a «#{@article.title}»"
  end
end
