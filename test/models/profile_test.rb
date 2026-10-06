require 'test_helper'

class ProfileTest < ActiveSupport::TestCase
  test "un profilo senza utente non è valido (belongs_to è obbligatorio)" do
    profile = Profile.new(name: "Senza utente")
    assert_not profile.valid?
    assert_includes profile.errors.full_messages, "Utente deve esistere"
  end

  test "create_profile collega il profilo all'utente" do
    profile = users(:two).create_profile(name: "Lettore", color: "blu")
    assert profile.persisted?
    assert_equal users(:two).id, profile.user_id
  end
end
