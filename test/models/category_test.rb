require 'test_helper'

class CategoryTest < ActiveSupport::TestCase
  test "le categorie sono sempre in ordine alfabetico (default_scope)" do
    assert_equal %w[NBA Tattica], Category.all.map(&:name)
  end

  test "ha molti articoli" do
    categories(:nba).articles << articles(:one)
    assert_equal [articles(:one)], categories(:nba).articles.to_a
  end
end
