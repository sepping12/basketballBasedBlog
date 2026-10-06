require 'test_helper'

class ArticleTest < ActiveSupport::TestCase
  test "titolo e testo sono obbligatori" do
    article = Article.new
    assert_not article.valid?
    assert_includes article.errors.full_messages, "Titolo è obbligatorio"
    assert_includes article.errors.full_messages, "Testo è obbligatorio"
  end

  test "un articolo con titolo e testo è valido anche senza utente" do
    assert Article.new(title: "Ciao", body: "Testo").valid?
  end

  test "latest_first mette per primo l'articolo più recente" do
    old = Article.create!(title: "Vecchio", body: "x", published_at: 2.days.ago)
    new = Article.create!(title: "Nuovo", body: "x", published_at: 1.hour.ago)
    assert_equal [new, old], Article.latest_first.where(id: [old.id, new.id]).to_a
  end

  test "published e draft distinguono per published_at" do
    assert_includes Article.published, articles(:one)
    assert_not_includes Article.published, articles(:two)
    assert_includes Article.draft, articles(:two)
  end

  test "published? dice se l'articolo è pubblicato" do
    assert articles(:one).published?
    assert_not articles(:two).published?
  end

  test "recent contiene solo gli articoli dell'ultima settimana" do
    nuovo = Article.create!(title: "Di oggi", body: "x", published_at: Time.zone.now)
    vecchio = Article.create!(title: "Di un mese fa", body: "x", published_at: 1.month.ago)
    assert_includes Article.recent, nuovo
    assert_not_includes Article.recent, vecchio
  end

  test "where_title cerca per parte del titolo" do
    assert_equal [articles(:one)], Article.where_title("pubblic").to_a
  end

  test "gli scope si concatenano" do
    assert_equal [articles(:two)], Article.draft.where_title("Bozza").to_a
  end

  test "long_title unisce titolo e data" do
    assert_equal "Articolo pubblicato - #{articles(:one).published_at}", articles(:one).long_title
  end

  test "un articolo appartiene a un utente e ha commenti" do
    assert_equal users(:one), articles(:one).user
    assert_equal [comments(:one)], articles(:one).comments.to_a
  end

  test "un articolo può avere più categorie e viceversa" do
    articles(:one).categories << categories(:tattica) << categories(:nba)
    assert_equal %w[NBA Tattica], articles(:one).categories.map(&:name)
    assert_includes categories(:tattica).articles, articles(:one)
  end
end
