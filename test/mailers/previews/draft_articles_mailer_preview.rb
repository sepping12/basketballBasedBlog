# Anteprime: http://localhost:3000/rails/mailers/draft_articles_mailer
class DraftArticlesMailerPreview < ActionMailer::Preview
  def no_author
    DraftArticlesMailer.no_author("lettore@example.com")
  end

  def invalid_draft
    DraftArticlesMailer.invalid_draft("autore@example.com", ["Titolo è obbligatorio"])
  end

  def created
    DraftArticlesMailer.created("autore@example.com", Article.first)
  end
end
