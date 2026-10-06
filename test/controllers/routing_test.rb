require 'test_helper'

# Capitolo 7: le route collegano URL + verbo HTTP a controller#azione.
class RoutingTest < ActionDispatch::IntegrationTest
  test "la root è la landing page" do
    assert_routing "/", controller: "pages", action: "home"
  end

  test "la route con nome chi-sono" do
    assert_routing "/chi-sono", controller: "pages", action: "about"
    assert_equal "/chi-sono", about_path
  end

  test "resources :articles crea le sette azioni REST" do
    assert_routing({ method: "get",    path: "/articles" },          { controller: "articles", action: "index" })
    assert_routing({ method: "post",   path: "/articles" },          { controller: "articles", action: "create" })
    assert_routing({ method: "get",    path: "/articles/new" },      { controller: "articles", action: "new" })
    assert_routing({ method: "get",    path: "/articles/1" },        { controller: "articles", action: "show", id: "1" })
    assert_routing({ method: "get",    path: "/articles/1/edit" },   { controller: "articles", action: "edit", id: "1" })
    assert_routing({ method: "patch",  path: "/articles/1" },        { controller: "articles", action: "update", id: "1" })
    assert_routing({ method: "delete", path: "/articles/1" },        { controller: "articles", action: "destroy", id: "1" })
  end

  test "lo stesso URL con verbi diversi va ad azioni diverse" do
    assert_recognizes({ controller: "articles", action: "show", id: "5" },    { method: :get,    path: "/articles/5" })
    assert_recognizes({ controller: "articles", action: "update", id: "5" },  { method: :patch,  path: "/articles/5" })
    assert_recognizes({ controller: "articles", action: "destroy", id: "5" }, { method: :delete, path: "/articles/5" })
  end

  test "le named route generano percorsi e URL" do
    assert_equal "/articles", articles_path
    assert_equal "/articles/7", article_path(7)
    assert_equal "/articles/7/edit", edit_article_path(7)
    assert_equal "/articles/new", new_article_path
    assert_equal "http://www.example.com/articles/7", article_url(7)
  end

  test "un oggetto viene trasformato nel suo percorso" do
    assert_equal article_path(articles(:one)), url_for(articles(:one)).sub("http://www.example.com", "")
  end
end
