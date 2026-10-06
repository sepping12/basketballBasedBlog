class Article < ApplicationRecord
  validates :title, :body, presence: true

  # Ogni articolo ha un autore. (Nel Capitolo 6 era `optional: true` perché non c'era ancora
  # il login; ora il controller crea gli articoli con current_user.articles.new.)
  belongs_to :user
  has_and_belongs_to_many :categories
  has_many :comments

  # Un'immagine di copertina. Active Storage la salva fuori dalla tabella articles
  # (tabelle active_storage_blobs e active_storage_attachments, "polimorfiche": servono per qualsiasi modello).
  has_one_attached :cover_image

  # Valore della checkbox "Rimuovi l'immagine" del form: non è una colonna, è solo un attributo "virtuale".
  attr_accessor :remove_cover_image
  after_save :purge_cover_image_if_requested

  # Active Storage (Rails 6.0) non ha validazioni integrate: le scriviamo noi.
  COVER_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
  COVER_MAX_SIZE = 5.megabytes
  validate :cover_image_must_be_a_valid_image

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

  private

  # Checkbox "Rimuovi questa immagine" spuntata (valore "1"): elimina la copertina dopo il salvataggio.
  # Poi azzera il flag: se si riusa lo STESSO oggetto e si allega un'altra immagine, non deve cancellare anche quella
  # (nel libro il flag restava "1" e la nuova copertina spariva subito).
  def purge_cover_image_if_requested
    return unless remove_cover_image == "1"
    cover_image.purge
    self.remove_cover_image = nil
  end

  # Solo immagini "da web" e non enormi. Niente SVG: può contenere JavaScript.
  def cover_image_must_be_a_valid_image
    return unless cover_image.attached?

    unless COVER_TYPES.include?(cover_image.blob.content_type)
      errors.add(:cover_image, "deve essere un'immagine JPEG, PNG, GIF o WebP")
    end
    if cover_image.blob.byte_size > COVER_MAX_SIZE
      errors.add(:cover_image, "è troppo grande (massimo #{COVER_MAX_SIZE / 1.megabyte} MB)")
    end
  end
end
