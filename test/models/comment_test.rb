require 'test_helper'

class CommentTest < ActiveSupport::TestCase
  test "nome, email e testo sono obbligatori" do
    comment = articles(:one).comments.build
    assert_not comment.valid?
    assert_includes comment.errors.full_messages, "Nome è obbligatorio"
    assert_includes comment.errors.full_messages, "Email è obbligatorio"
    assert_includes comment.errors.full_messages, "Commento è obbligatorio"
  end

  test "non si può commentare un articolo non ancora pubblicato" do
    comment = articles(:two).comments.create(name: "Dude", email: "dude@example.com", body: "Great!")
    assert_not comment.persisted?
    assert_equal ["Articolo non è ancora pubblicato"], comment.errors.full_messages
  end

  test "si può commentare un articolo pubblicato" do
    comment = nil
    assert_emails 1 do
      comment = articles(:one).comments.create(name: "Dude", email: "dude@example.com", body: "Great!")
    end
    assert comment.persisted?
    assert_equal ["autore@example.com"], ActionMailer::Base.deliveries.last.to
  end

  test "il commento accoda un job per l'email, senza consegnarla subito" do
    assert_enqueued_emails(1) do
      articles(:one).comments.create!(name: "Dude", email: "dude@example.com", body: "Great!")
    end
    assert_empty ActionMailer::Base.deliveries
  end

  test "un commento non valido non accoda niente" do
    assert_no_enqueued_emails do
      articles(:one).comments.create(name: "", email: "", body: "")
    end
  end

  test "se l'articolo sparisce prima che il job giri, il job viene scartato senza errori" do
    comment = articles(:one).comments.create!(name: "Dude", email: "dude@example.com", body: "Great!")
    comment.destroy
    # Si esegue il job "a mano" (perform_enqueued_jobs istanzia i job per filtrarli e fallirebbe prima).
    dati = enqueued_jobs.first
    assert_nothing_raised do
      ActiveJob::Base.execute("job_class" => dati[:job].to_s, "job_id" => SecureRandom.uuid, "queue_name" => dati[:queue],
                              "arguments" => dati[:args], "executions" => 0, "locale" => "it", "timezone" => "UTC")
    end
    assert_empty ActionMailer::Base.deliveries
  end
end
