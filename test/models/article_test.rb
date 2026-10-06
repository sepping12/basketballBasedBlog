require 'test_helper'

class ArticleTest < ActiveSupport::TestCase
  test "titolo e testo sono obbligatori" do
    article = Article.new
    assert_not article.valid?
    assert_includes article.errors.full_messages, "Titolo è obbligatorio"
    assert_includes article.errors.full_messages, "Testo è obbligatorio"
  end

  test "un articolo con titolo e testo è valido" do
    assert Article.new(title: "Ciao", body: "Testo").valid?
  end

  test "recent mette per primo l'articolo più recente" do
    old = Article.create!(title: "Vecchio", body: "x", published_at: 2.days.ago)
    new = Article.create!(title: "Nuovo", body: "x", published_at: 1.hour.ago)
    assert_equal [new, old], Article.recent.where(id: [old.id, new.id]).to_a
  end
end
