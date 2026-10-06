class Comment < ApplicationRecord
  belongs_to :article

  validates :name, :email, :body, presence: true
  validate :article_should_be_published

  after_create :email_article_author

  def article_should_be_published
    errors.add(:article_id, "non è ancora pubblicato") if article && !article.published?
  end

  # Avvisa per email l'autore dell'articolo (NotifierMailer#comment_added).
  # deliver_now = si invia subito, DENTRO la richiesta web: se il server di posta è lento, rallenta chi commenta.
  # (Il Capitolo 13, Active Job, lo sposta in background con deliver_later.)
  def email_article_author
    NotifierMailer.comment_added(self).deliver_now if article.user
  end
end
