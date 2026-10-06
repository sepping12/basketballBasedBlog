class Article < ApplicationRecord
  validates :title, :body, presence: true

  # Nel libro (Listato 6-6) è `belongs_to :user`, obbligatorio. Qui è facoltativo
  # perché nel blog non c'è ancora il login (Capitolo 8): il form non sa chi è
  # l'autore e tutti i salvataggi fallirebbero con "Utente deve esistere".
  belongs_to :user, optional: true
  has_and_belongs_to_many :categories
  has_many :comments

  scope :published, -> { where.not(published_at: nil) }
  scope :draft, -> { where(published_at: nil) }
  scope :recent, -> { where('articles.published_at > ?', 1.week.ago.to_date) }
  scope :where_title, -> (term) { where("articles.title LIKE ?", "%#{term}%") }

  # Ordine per le pagine pubbliche: dal più recente (data di pubblicazione, o di
  # creazione se manca). Era `recent` nel passo 9: il nome è ora usato dal libro.
  scope :latest_first, -> { order(Arel.sql("COALESCE(published_at, created_at) DESC")) }

  def long_title
    "#{title} - #{published_at}"
  end

  def published?
    published_at.present?
  end
end
