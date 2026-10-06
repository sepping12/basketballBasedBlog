require 'test_helper'

class UserTest < ActiveSupport::TestCase
  def nuovo(attrs = {})
    User.new({ email: "nuovo@example.com", password: "secret", password_confirmation: "secret" }.merge(attrs))
  end

  test "un utente valido" do
    assert nuovo.valid?
  end

  test "l'email deve essere unica" do
    assert_not nuovo(email: users(:one).email).valid?
  end

  test "l'email deve avere un formato valido" do
    assert_not nuovo(email: "non-una-email").valid?
    assert_not nuovo(email: "a@b").valid?
  end

  test "l'email deve essere lunga tra 5 e 50 caratteri" do
    assert_not nuovo(email: "a@b.c").valid?          # 5 caratteri ma formato non valido
    assert_not nuovo(email: "#{'a' * 50}@example.com").valid?
  end

  test "la password è obbligatoria, lunga 4-20 caratteri e confermata" do
    assert_not nuovo(password: nil, password_confirmation: nil).valid?
    assert_not nuovo(password: "abc", password_confirmation: "abc").valid?
    assert_not nuovo(password: "secret", password_confirmation: "diversa").valid?
  end

  test "la password in chiaro non viene salvata: si salva l'hash" do
    user = nuovo
    user.save!
    assert_equal Digest::SHA1.hexdigest("secret"), user.reload.hashed_password
    assert_nil User.find(user.id).password
  end

  test "authenticate restituisce l'utente con la password giusta, nil con quella sbagliata" do
    assert_equal users(:one), User.authenticate("autore@example.com", "secret")
    assert_nil User.authenticate("autore@example.com", "sbagliata")
    assert_nil User.authenticate("sconosciuto@example.com", "secret")
  end

  test "un utente esistente si può salvare senza reimpostare la password" do
    assert users(:one).update(email: "altro@example.com")
  end

  test "ha un profilo e molti articoli" do
    assert_equal profiles(:one), users(:one).profile
    assert_equal [articles(:one)], users(:one).articles.to_a
  end

  test "replies sono i commenti ricevuti sugli articoli dell'utente" do
    assert_equal [comments(:one)], users(:one).replies.to_a
  end

  test "eliminando un utente i suoi articoli restano senza autore (:nullify) e il profilo sparisce (:destroy)" do
    users(:one).destroy
    assert_nil articles(:one).reload.user_id
    assert_equal 0, Profile.where(user_id: users(:one).id).count
  end
end
