require 'test_helper'

# Capitolo 11: il testo dell'articolo è un rich text (Action Text)
class ArticleRichTextTest < ActiveSupport::TestCase
  setup { @article = articles(:one) }

  test "body non è più una colonna di articles: è un rich text in un'altra tabella" do
    assert_not Article.column_names.include?("body")
    assert_kind_of ActionText::RichText, @article.body
    assert_equal "Article", ActionText::RichText.find_by(record_id: @article.id, name: "body").record_type
  end

  test "si assegna HTML e si legge come HTML o come testo semplice" do
    @article.update!(body: "<p>Una <strong>grande</strong> partita.</p>")
    assert_includes @article.reload.body.to_s, "<strong>grande</strong>"
    assert_equal "Una grande partita.", @article.body.to_plain_text
  end

  test "to_plain_text toglie i tag e mantiene gli elenchi leggibili" do
    @article.update!(body: "<div>Titolo</div><ul><li>uno</li><li>due</li></ul>")
    testo = @article.body.to_plain_text
    assert_includes testo, "uno"
    assert_includes testo, "due"
    assert_no_match(/<|>/, testo)
  end

  test "il testo è ancora obbligatorio" do
    articolo = Article.new(title: "x", user: users(:one), body: "")
    assert_not articolo.valid?
    assert_includes articolo.errors.full_messages, "Testo è obbligatorio"
  end

  test "un testo fatto solo di spazi o di a-capo (un editor 'vuoto') è considerato vuoto" do
    articolo = Article.new(title: "x", user: users(:one), body: "<div><br></div>")
    assert_not articolo.valid?
    assert_includes articolo.errors.full_messages, "Testo è obbligatorio"
  end

  test "un articolo con testo valido si salva e crea una riga in action_text_rich_texts" do
    assert_difference("ActionText::RichText.count") do
      Article.create!(title: "Nuovo", user: users(:one), body: "<p>Testo</p>")
    end
  end

  test "il tempo di lettura conta le PAROLE, non i tag HTML" do
    parole = (["parola"] * 400).join(" ")
    @article.update!(body: "<p><strong>#{parole}</strong></p>")
    # 400 parole = 2 minuti; se contasse anche "<p><strong>…" non cambierebbe, ma il testo sarebbe diverso
    assert_equal 400, @article.body.to_plain_text.split.size
    assert_equal "2 min di lettura", ApplicationController.helpers.reading_time(@article)
  end

  test "eliminando l'articolo si elimina anche il suo testo (dependent: :destroy implicito)" do
    assert_difference("ActionText::RichText.count", -1) { @article.destroy }
  end

  test "la conversione della migrazione: paragrafi, a-capo e HTML neutralizzato" do
    require Rails.root.join(Dir["db/migrate/*migrate_article_body_to_action_text.rb"].first)
    converti = ->(testo) { MigrateArticleBodyToActionText.new.send(:testo_in_html, testo) }
    assert_equal "<p>Primo.</p><p>Secondo<br>su due righe</p>", converti.call("Primo.\n\nSecondo\nsu due righe")
    assert_equal "<p>&lt;b&gt;non grassetto&lt;/b&gt; &amp; co</p>", converti.call("<b>non grassetto</b> & co")
    assert_equal "", converti.call(nil)
    assert_equal "<p>uno</p><p>due</p>", converti.call("  uno \r\n\r\n due  ")
  end

  test "un'immagine incorporata nel testo crea un allegato di Active Storage sul rich text" do
    blob = ActiveStorage::Blob.create_after_upload!(io: File.open(file_fixture("copertina.png")), filename: "copertina.png", content_type: "image/png")
    attachment = ActionText::Attachment.from_attachable(blob)
    @article.update!(body: "<p>Guarda:</p>#{attachment.to_html}")
    assert_equal [blob], @article.reload.body.embeds.map(&:blob)
    assert_equal "ActionText::RichText", ActiveStorage::Attachment.find_by(blob_id: blob.id).record_type
  end
end
