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
    assert_output(/We will notify autore@example.com in Chapter 12/) do
      comment = articles(:one).comments.create(name: "Dude", email: "dude@example.com", body: "Great!")
    end
    assert comment.persisted?
  end

  test "il callback non fallisce se l'articolo non ha un autore" do
    senza_autore = Article.create!(title: "Anonimo", body: "x", published_at: 1.day.ago)
    assert_output("") do
      assert senza_autore.comments.create(name: "A", email: "a@example.com", body: "x").persisted?
    end
  end
end
