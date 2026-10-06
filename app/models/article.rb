class Article < ApplicationRecord
  validates :title, :body, presence: true

  # Ogni articolo ha un autore. (Nel Capitolo 6 era `optional: true` perché non c'era ancora
  # il login; ora il controller crea gli articoli con current_user.articles.new.)
  belongs_to :user
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

  # L'articolo appartiene a questo utente? (nil, o un non-utente, dà sempre false)
  def owned_by?(owner)
    return false unless owner.is_a?(User)
    user == owner
  end
end
