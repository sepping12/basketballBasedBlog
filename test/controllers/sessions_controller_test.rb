require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "la pagina di login si vede" do
    get login_url
    assert_response :success
    assert_select "form[action='#{session_path}'] input[name=email]"
    assert_select "form input[type=password][name=password]"
  end

  test "login con credenziali giuste: redirect e utente in sessione" do
    log_in_as users(:one)
    assert_redirected_to root_path
    assert_equal users(:one).id, session[:user_id]
    assert_equal "Accesso effettuato.", flash[:notice]
  end

  test "login con password sbagliata: niente sessione, errore generico" do
    log_in_as users(:one), password: "sbagliata"
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
    assert_select ".toast--alert", text: "Email o password non corretti."
  end

  test "login con email inesistente dà lo stesso errore (non rivela quali email esistono)" do
    post session_path, params: { email: "nessuno@example.com", password: "secret" }
    assert_response :unprocessable_entity
    assert_select ".toast--alert", text: "Email o password non corretti."
  end

  test "logout azzera la sessione" do
    log_in_as users(:one)
    delete logout_path
    assert_redirected_to root_path
    assert_nil session[:user_id]
    follow_redirect!
    assert_select ".toast", text: "Sei uscito."
  end

  test "il logout è un DELETE: una GET non fa nulla" do
    log_in_as users(:one)
    assert_raises(ActionController::RoutingError) { get "/logout" }
    assert_equal users(:one).id, session[:user_id]
  end

  test "dopo il login si torna alla pagina che si voleva vedere" do
    get new_article_path
    assert_redirected_to login_path
    log_in_as users(:one)
    assert_redirected_to new_article_path
  end

  test "la navbar cambia con lo stato di login" do
    get root_path
    assert_select "nav a[href='#{login_path}']"
    assert_select "nav a[href='#{new_user_path}']"
    assert_select "nav a[href='#{new_article_path}']", count: 0

    log_in_as users(:one)
    get root_path
    assert_select "nav a[href='#{login_path}']", count: 0
    assert_select "nav a[href='#{logout_path}'][data-method=delete]"
    assert_select "nav a[href='#{new_article_path}']"
  end
end
