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
end
