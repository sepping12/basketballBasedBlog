require 'test_helper'

# Capitolo 12: le email del blog
class NotifierMailerTest < ActionMailer::TestCase
  setup { @article = articles(:one) }

  # --- "Invia a un amico" ---------------------------------------------------------------

  test "email_friend: destinatario, mittente e oggetto" do
    email = NotifierMailer.email_friend(@article, "Marco", "amico@example.com")
    assert_equal ["amico@example.com"], email.to
    assert_equal ["blog@example.com"], email.from
    assert_equal "Marco ti consiglia un articolo: Articolo pubblicato", email.subject
  end

  test "email_friend: è multipart con la versione in testo e quella HTML" do
    email = NotifierMailer.email_friend(@article, "Marco", "amico@example.com")
    assert email.multipart?
    assert_equal %w[text/plain text/html], email.parts.map(&:mime_type)
  end

  test "email_friend: il testo contiene mittente, titolo, estratto e il LINK all'articolo" do
    testo = NotifierMailer.email_friend(@article, "Marco", "amico@example.com").text_part.body.to_s
    assert_includes testo, "Marco"
    assert_includes testo, "Articolo pubblicato"
    assert_includes testo, "Un estratto"
    assert_includes testo, "http://www.example.com/articles/#{@article.id}"
  end

  test "email_friend: l'HTML ha il link e il nome del mittente è neutralizzato (niente HTML iniettato)" do
    html = NotifierMailer.email_friend(@article, "<b>Furbo</b>", "amico@example.com").html_part.body.to_s
    assert_includes html, %(href="http://www.example.com/articles/#{@article.id}")
    assert_includes html, "&lt;b&gt;Furbo&lt;/b&gt;"
    assert_not_includes html, "<b>Furbo</b>"
  end

  test "email_friend: senza copertina non ci sono allegati" do
    assert_empty NotifierMailer.email_friend(@article, "Marco", "amico@example.com").attachments
  end

  test "email_friend: con una copertina allega l'immagine (Active Storage)" do
    attach_cover(@article).save!
    email = NotifierMailer.email_friend(@article, "Marco", "amico@example.com")
    assert_equal 1, email.attachments.size
    assert_equal "copertina.png", email.attachments.first.filename
    assert_equal File.binread(file_fixture("copertina.png")), email.attachments.first.body.decoded
  end

  # --- avviso di un nuovo commento -----------------------------------------------------------

  test "comment_added: arriva all'AUTORE dell'articolo" do
    commento = comments(:one)
    email = NotifierMailer.comment_added(commento)
    assert_equal ["autore@example.com"], email.to
    assert_equal "Nuovo commento a «Articolo pubblicato»", email.subject
  end

  test "comment_added: dice chi ha commentato, mostra il commento e rimanda alla sezione commenti" do
    email = NotifierMailer.comment_added(comments(:one))
    [email.text_part.body.to_s, email.html_part.body.to_s].each do |corpo|
      assert_includes corpo, "Ospite"
      assert_includes corpo, "articles/#{@article.id}#commenti"
    end
    assert_includes email.text_part.body.to_s, "Bell'articolo!"
  end

  test "comment_added: un commento lunghissimo viene accorciato" do
    lungo = comments(:one).tap { |c| c.body = "parola " * 200 }
    assert_operator NotifierMailer.comment_added(lungo).text_part.body.to_s.length, :<, 700
  end

  test "comment_added: il testo del commento nell'HTML è neutralizzato" do
    sporco = comments(:one).tap { |c| c.body = "<script>alert(1)</script>ciao" }
    html = NotifierMailer.comment_added(sporco).html_part.body.to_s
    assert_not_includes html, "<script>"
  end
end
