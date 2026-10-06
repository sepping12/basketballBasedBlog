class Comment < ApplicationRecord
  belongs_to :article

  validates :name, :email, :body, presence: true
  validate :article_should_be_published

  after_create :email_article_author

  def article_should_be_published
    errors.add(:article_id, "non è ancora pubblicato") if article && !article.published?
  end

  # L'email vera arriva nel Capitolo 12: per ora stampiamo soltanto.
  def email_article_author
    puts "We will notify #{article.user.email} in Chapter 12" if article.user
  end
end
