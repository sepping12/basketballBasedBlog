# Anteprime dei messaggi: http://localhost:3000/rails/mailers/notifier_mailer
# Non inviano nulla: mostrano l'email (HTML e testo) con questi dati d'esempio.
class NotifierMailerPreview < ActionMailer::Preview
  def email_friend
    NotifierMailer.email_friend(Article.published.first || Article.first, "Marco Rossi", "amico@example.com")
  end

  def comment_added
    # build, NON create: l'anteprima non deve aggiungere commenti al database.
    articolo = Article.published.first || Article.first
    commento = articolo.comments.build(name: "Lettore Anonimo", email: "lettore@example.com",
                                       body: "Questo articolo mi ha fatto capire il pick and roll!")
    NotifierMailer.comment_added(commento)
  end
end
