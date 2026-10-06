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

  # --- Capitolo 12: l'indirizzo segreto per le bozze (Action Mailbox) ---

  test "ogni nuovo utente riceve un token casuale e unico" do
    post users_url, params: { user: { email: "nuovo@example.com", password: "secret", password_confirmation: "secret" } }
    token = User.find_by!(email: "nuovo@example.com").draft_article_token
    assert_equal 24, token.length
    assert_not_equal users(:one).draft_article_token, token
  end

  test "il token è unico: due utenti non possono averlo uguale (indice unique)" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      users(:two).update_column(:draft_article_token, users(:one).draft_article_token)
    end
  end

  test "la pagina del proprio account mostra l'indirizzo per le bozze e il pulsante per cambiarlo" do
    log_in_as users(:one)
    get edit_user_url(users(:one))
    assert_select "#bozze-email a[href='mailto:#{users(:one).draft_article_email}']"
    assert_select "#bozze-email form[action='#{regenerate_draft_token_user_path(users(:one))}']"
  end

  test "rigenerare il token cambia l'indirizzo" do
    log_in_as users(:one)
    vecchio = users(:one).draft_article_email
    post regenerate_draft_token_user_url(users(:one))
    assert_redirected_to edit_user_path(users(:one))
    assert_not_equal vecchio, users(:one).reload.draft_article_email
  end

  test "rigenerare richiede il login, e agisce solo su se stessi (l'id nell'URL è ignorato)" do
    post regenerate_draft_token_url(users(:one)) rescue nil
    vecchio_due = users(:two).draft_article_token
    log_in_as users(:one)
    post regenerate_draft_token_user_url(users(:two))
    assert_equal vecchio_due, users(:two).reload.draft_article_token
  end
end

