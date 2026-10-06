class Comment < ApplicationRecord
  belongs_to :article

  validates :name, :email, :body, presence: true
  validate :article_should_be_published

  # after_create_commit, NON after_create: il job gira in un altro thread e deve trovare il commento già nel DB.
  # after_create scatta DENTRO la transazione: un job veloce potrebbe partire prima del commit e non trovare la riga.
  after_create_commit :email_article_author

  def article_should_be_published
    errors.add(:article_id, "non è ancora pubblicato") if article && !article.published?
  end

  # Avvisa per email l'autore dell'articolo (NotifierMailer#comment_added).
  # deliver_later = l'invio avviene in un job in background (Active Job): chi commenta non aspetta il server di posta.
  def email_article_author
    NotifierMailer.comment_added(self).deliver_later if article.user
  end
end
