require 'test_helper'

# Capitolo 10: la copertina dell'articolo (Active Storage)
class ArticleCoverTest < ActiveSupport::TestCase
  setup { @article = articles(:one) }

  test "un articolo parte senza copertina" do
    assert_not @article.cover_image.attached?
  end

  test "un'immagine PNG si allega e l'articolo resta valido" do
    attach_cover(@article)
    assert @article.cover_image.attached?
    assert @article.valid?
    assert_equal "image/png", @article.cover_image.blob.content_type
    assert_equal "copertina.png", @article.cover_image.filename.to_s
  end

  test "il tipo di file viene riconosciuto dal CONTENUTO (Active Storage), non solo dal nome" do
    attach_cover(@article, "panoramica.jpg", "image/jpeg")
    assert_equal "image/jpeg", @article.cover_image.blob.content_type
  end

  test "un file di testo NON è una copertina valida" do
    attach_cover(@article, "appunti.txt", "text/plain")
    assert_not @article.valid?
    assert_includes @article.errors.full_messages, "Copertina deve essere un'immagine JPEG, PNG, GIF o WebP"
  end

  test "un SVG è rifiutato (può contenere JavaScript)" do
    attach_cover(@article, "logo.svg", "image/svg+xml")
    assert_not @article.valid?
    assert_includes @article.errors.full_messages, "Copertina deve essere un'immagine JPEG, PNG, GIF o WebP"
  end

  test "un file troppo grande è rifiutato" do
    Tempfile.create(["enorme", ".png"]) do |f|
      f.binmode
      f.write(File.binread(file_fixture("copertina.png")))
      f.write("\0" * (Article::COVER_MAX_SIZE + 1))      # un PNG "gonfiato" oltre il limite
      f.flush
      @article.cover_image.attach(io: File.open(f.path), filename: "enorme.png", content_type: "image/png")
    end
    assert_not @article.valid?
    assert_includes @article.errors.full_messages, "Copertina è troppo grande (massimo 5 MB)"
  end

  test "remove_cover_image = '1' elimina la copertina dopo il salvataggio" do
    attach_cover(@article)
    @article.save!
    assert_difference("ActiveStorage::Blob.count", -1) do
      @article.update!(remove_cover_image: "1")
    end
    assert_not @article.reload.cover_image.attached?
  end

  test "dopo la rimozione si può allegare un'altra copertina sullo stesso oggetto (il flag si azzera)" do
    attach_cover(@article)
    @article.save!
    @article.update!(remove_cover_image: "1")
    assert_nil @article.remove_cover_image
    attach_cover(@article, "panoramica.jpg", "image/jpeg")
    assert @article.reload.cover_image.attached?
    assert_equal "panoramica.jpg", @article.cover_image.filename.to_s
  end

  test "remove_cover_image = '0' (checkbox non spuntata) lascia la copertina" do
    attach_cover(@article)
    @article.save!
    @article.update!(remove_cover_image: "0")
    assert @article.reload.cover_image.attached?
  end

  test "remove_cover_image è un attributo virtuale: non è una colonna" do
    assert_not Article.column_names.include?("remove_cover_image")
    assert_nil @article.remove_cover_image
  end

  test "i file stanno in tabelle polimorfiche, non in articles" do
    attach_cover(@article)
    @article.save!
    attachment = ActiveStorage::Attachment.find_by!(record_id: @article.id, name: "cover_image")
    assert_equal "Article", attachment.record_type
    assert_equal @article, attachment.record
    assert_not Article.column_names.any? { |c| c.include?("cover") }
  end

  test "la variante è una copia ridimensionata, non l'originale" do
    skip "ImageMagick non installato" unless imagemagick_disponibile?
    attach_cover(@article)
    @article.save!
    variante = @article.cover_image.variant(resize_to_limit: [100, 100]).processed
    img = MiniMagick::Image.read(variante.service.download(variante.key))
    assert_operator img.width, :<=, 100
    assert_operator img.height, :<=, 100
    assert_equal 600, @article.cover_image.blob.tap(&:analyze).metadata[:width]   # l'originale resta com'era
  end

  test "resize_to_fill ritaglia alle dimensioni esatte" do
    skip "ImageMagick non installato" unless imagemagick_disponibile?
    attach_cover(@article)
    @article.save!
    variante = @article.cover_image.variant(resize_to_fill: [640, 360]).processed
    img = MiniMagick::Image.read(variante.service.download(variante.key))
    assert_equal [640, 360], [img.width, img.height]
  end
end
