require "test_helper"

class DraftArticlesMailerTest < ActionMailer::TestCase
  test "no_author: messaggio di errore al mittente, con contenuto in linea (HTML e testo)" do
    email = DraftArticlesMailer.no_author("lettore@example.com")
    assert_equal ["lettore@example.com"], email.to
    assert_equal "Non è stato possibile elaborare la tua email", email.subject
    assert email.multipart?
    assert_includes email.text_part.body.to_s, "Controlla l'indirizzo per le bozze"
  end

  test "invalid_draft: elenca i motivi" do
    email = DraftArticlesMailer.invalid_draft("autore@example.com", ["Titolo è obbligatorio", "Testo è obbligatorio"])
    assert_includes email.text_part.body.to_s, "Titolo è obbligatorio e Testo è obbligatorio"
  end

  test "created: conferma con il link per MODIFICARE la bozza" do
    email = DraftArticlesMailer.created("autore@example.com", articles(:two))
    assert_equal "La tua bozza è stata creata", email.subject
    assert_includes email.text_part.body.to_s, "http://www.example.com/articles/#{articles(:two).id}/edit"
    assert_includes email.html_part.body.to_s, "Bozza di prova"
  end
end
