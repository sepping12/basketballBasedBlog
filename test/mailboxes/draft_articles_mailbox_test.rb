require "test_helper"

# Capitolo 12: creare bozze di articoli scrivendo un'email (Action Mailbox)
class DraftArticlesMailboxTest < ActionMailbox::TestCase
  setup do
    @autore = users(:one)
    @indirizzo = @autore.draft_article_email          # "<token>@drafts.example.com"
  end

  # body: :nessuno = non passare il corpo (serve quando il messaggio è costruito dal blocco, es. multipart)
  def ricevi(to: @indirizzo, from: "autore@example.com", subject: "Idea per un articolo", body: "Primo paragrafo.\n\nSecondo.", &blocco)
    opzioni = { to: to, from: from, subject: subject }
    opzioni[:body] = body unless body == :nessuno
    # Costruisco il messaggio io (Mail.new accetta il blocco per le parti) e lo "ricevo" come testo grezzo:
    # receive_inbound_email_from_mail di Rails 6.0 non passa il blocco a Mail.new.
    receive_inbound_email_from_source(Mail.new(opzioni, &blocco).to_s)
  end

  test "l'indirizzo personale è <token>@<dominio delle bozze>" do
    assert_equal "tokenAutoreUno1234567890@drafts.example.com", @indirizzo
  end

  test "un'email all'indirizzo dell'autore crea una BOZZA a suo nome" do
    assert_difference("Article.count") { ricevi }
    bozza = Article.order(:id).last
    assert_equal "Idea per un articolo", bozza.title                 # oggetto → titolo
    assert_equal @autore, bozza.user                                 # l'autore è chi ha il token
    assert_nil bozza.published_at                                    # è una bozza, non è pubblicata
    assert_not bozza.published?
  end

  test "il testo diventa HTML: i paragrafi (righe vuote) diventano <p>" do
    ricevi(body: "Primo paragrafo.\n\nSecondo\nsu due righe.")
    html = Article.order(:id).last.body.body.to_html
    assert_equal "<p>Primo paragrafo.</p><p>Secondo<br>su due righe.</p>", html
  end

  test "l'HTML scritto nell'email viene neutralizzato (non diventa HTML vero)" do
    ricevi(body: "<script>alert('xss')</script> e <b>grassetto?</b>")
    html = Article.order(:id).last.body.body.to_html
    assert_no_match(/<script|<b>/, html)
    assert_includes html, "&lt;script&gt;"
  end

  test "l'email è marcata come consegnata e l'autore riceve la conferma con il link per modificare la bozza" do
    assert_emails 1 do
      inbound = ricevi
      assert_equal "delivered", inbound.reload.status
    end
    conferma = ActionMailer::Base.deliveries.last
    assert_equal ["autore@example.com"], conferma.to
    assert_equal "La tua bozza è stata creata", conferma.subject
    assert_includes conferma.text_part.body.to_s, "/articles/#{Article.order(:id).last.id}/edit"
  end

  test "un indirizzo sconosciuto rimbalza: nessuna bozza e un messaggio al mittente" do
    assert_no_difference("Article.count") do
      assert_emails 1 do
        inbound = ricevi(to: "tokeninesistente@drafts.example.com")
        assert_equal "bounced", inbound.reload.status
      end
    end
    assert_equal "Non è stato possibile elaborare la tua email", ActionMailer::Base.deliveries.last.subject
    assert_equal ["autore@example.com"], ActionMailer::Base.deliveries.last.to
  end

  test "senza oggetto non si crea nulla e si risponde spiegando il motivo" do
    assert_no_difference("Article.count") do
      assert_emails 1 do
        inbound = ricevi(subject: "")
        assert_equal "bounced", inbound.reload.status
      end
    end
    assert_includes ActionMailer::Base.deliveries.last.text_part&.body.to_s.presence || ActionMailer::Base.deliveries.last.body.to_s, "Titolo è obbligatorio"
  end

  test "senza testo non si crea nulla" do
    assert_no_difference("Article.count") { ricevi(body: "   ") }
  end

  test "ogni utente ha il suo indirizzo: l'email va all'autore giusto" do
    ricevi(to: users(:two).draft_article_email, from: "lettore@example.com")
    assert_equal users(:two), Article.order(:id).last.user
  end

  test "il dominio si confronta senza distinguere maiuscole e minuscole" do
    assert_difference("Article.count") { ricevi(to: @indirizzo.sub("drafts.example.com", "DRAFTS.Example.COM")) }
  end

  test "l'email MULTIPART: si usa la parte di solo testo" do
    ricevi(body: :nessuno) do
      text_part { body "Testo semplice." }
      html_part { content_type "text/html; charset=UTF-8"; body "<p>Versione <b>HTML</b></p>" }
    end
    assert_equal "Testo semplice.", Article.order(:id).last.body.to_plain_text
  end

  test "un'email con solo HTML: si tolgono i tag" do
    ricevi(body: :nessuno) do
      content_type "text/html; charset=UTF-8"
      body "<p>Solo <b>HTML</b></p>"
    end
    assert_equal "Solo HTML", Article.order(:id).last.body.to_plain_text
  end

  test "un'email a un altro dominio non corrisponde a nessuna mailbox" do
    assert_raises(ActionMailbox::Router::RoutingError) { ricevi(to: "qualcuno@altrodominio.it") }
  end

  test "dopo aver rigenerato il token il vecchio indirizzo non funziona più" do
    vecchio = @indirizzo
    @autore.regenerate_draft_article_token
    assert_no_difference("Article.count") { ricevi(to: vecchio) }
    assert_difference("Article.count") { ricevi(to: @autore.reload.draft_article_email) }
  end
end
