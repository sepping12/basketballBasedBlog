class Article < ApplicationRecord
  validates :title, :body, presence: { message: "è obbligatorio" }

  # Dal più recente: usa la data di pubblicazione, o di creazione se manca.
  scope :recent, -> { order(Arel.sql("COALESCE(published_at, created_at) DESC")) }
end
