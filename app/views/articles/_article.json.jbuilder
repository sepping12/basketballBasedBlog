json.extract! article, :id, :title, :location, :excerpt, :published_at, :created_at, :updated_at
# body è un rich text: lo si espone sia come testo semplice sia come HTML (già sanificato).
json.body article.body.to_plain_text
# Il rich text si trasforma in HTML con un template HTML (action_text/content/_layout), cercato con il formato
# della richiesta: in una risposta JSON non c'è. Per questo si indica un "renderer" che lavora in HTML.
json.body_html ActionText::Content.with_renderer(ApplicationController.renderer) { article.body.to_s }
json.url article_url(article, format: :json)
# URL dell'immagine ORIGINALE (se c'è): è un link firmato di Active Storage che rimanda al file.
json.cover_image_url rails_blob_url(article.cover_image) if article.cover_image.attached?
