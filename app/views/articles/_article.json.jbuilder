json.extract! article, :id, :title, :location, :excerpt, :body, :published_at, :created_at, :updated_at
json.url article_url(article, format: :json)
# URL dell'immagine ORIGINALE (se c'è): è un link firmato di Active Storage che rimanda al file.
json.cover_image_url rails_blob_url(article.cover_image) if article.cover_image.attached?
