require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "la pagina di registrazione si vede" do
    get new_user_url
    assert_response :success
    assert_select "form input[name='user[email]']"
    assert_select "form input[type=password][name='user[password]']"
  end

  test "registrazione valida: crea l'utente (con password cifrata) e rimanda al login" do
    assert_difference("User.count") do
      post users_url, params: { user: { email: "nuovo@example.com", password: "secret", password_confirmation: "secret" } }
    end
    assert_redirected_to login_path
    assert_equal Digest::SHA1.hexdigest("secret"), User.find_by!(email: "nuovo@example.com").hashed_password
  end

  test "registrazione non valida: 422 con gli errori in italiano" do
    assert_no_difference("User.count") do
      post users_url, params: { user: { email: "non-una-email", password: "abc", password_confirmation: "diversa" } }
    end
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: "Email non è valido"
    assert_select "#error_explanation li", text: /Conferma password non coincide/
  end

  test "strong parameters: non si possono impostare altri campi (es. hashed_password)" do
    post users_url, params: { user: { email: "furbo@example.com", password: "secret", password_confirmation: "secret",
                                      hashed_password: "scelta-da-me" } }
    assert_equal Digest::SHA1.hexdigest("secret"), User.find_by!(email: "furbo@example.com").hashed_password
  end

  test "modificare i propri dati richiede il login" do
    get edit_user_url(users(:one))
    assert_redirected_to login_path
    patch user_url(users(:one)), params: { user: { email: "altra@example.com" } }
    assert_redirected_to login_path
    assert_equal "autore@example.com", users(:one).reload.email
  end

  test "si modifica la propria email senza dover reinserire la password" do
    log_in_as users(:one)
    get edit_user_url(users(:one))
    assert_response :success
    patch user_url(users(:one)), params: { user: { email: "nuova@example.com", password: "", password_confirmation: "" } }
    assert_redirected_to root_path
    assert_equal "nuova@example.com", users(:one).reload.email
    assert User.authenticate("nuova@example.com", "secret")       # la password è rimasta quella
  end

  test "si cambia la password" do
    log_in_as users(:one)
    patch user_url(users(:one)), params: { user: { password: "nuova1", password_confirmation: "nuova1" } }
    assert User.authenticate("autore@example.com", "nuova1")
    assert_nil User.authenticate("autore@example.com", "secret")
  end

  test "l'id nell'URL è ignorato: non si può modificare un altro utente" do
    log_in_as users(:one)
    patch user_url(users(:two)), params: { user: { email: "rubata@example.com" } }
    assert_equal "lettore@example.com", users(:two).reload.email
    assert_equal "rubata@example.com", users(:one).reload.email    # ha modificato SE STESSO
  end
end
