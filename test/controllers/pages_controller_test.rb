require 'test_helper'

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "la landing page risponde e ha la navbar" do
    get root_url
    assert_response :success
    assert_select "nav.nav a.nav__link", minimum: 3
    assert_select "h1.hero__title"
  end

  test "la pagina chi sono risponde" do
    get about_url
    assert_response :success
    assert_select "h1.page-head__title"
  end

  test "la home mostra gli ultimi articoli" do
    get root_url
    assert_select ".card", count: [Article.published.count, 3].min
  end
end
