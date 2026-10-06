ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

# Active Storage nei test salva i file in tmp/storage: li togliamo a fine esecuzione.
Minitest.after_run { FileUtils.rm_rf(Rails.root.join("tmp/storage")) }

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # assert_emails, ActionMailer::Base.deliveries… anche nei test di modello.
  include ActionMailer::TestHelper

  # Add more helper methods to be used by all tests here...

  # Allega un file di test (test/fixtures/files) come copertina di un articolo.
  def attach_cover(article, nome = "copertina.png", tipo = "image/png")
    article.cover_image.attach(io: File.open(file_fixture(nome)), filename: nome, content_type: tipo)
    article
  end

  # I test sulle miniature richiedono ImageMagick (o libvips): se manca, vengono saltati.
  def imagemagick_disponibile?
    system("which magick > /dev/null 2>&1") || system("which convert > /dev/null 2>&1")
  end
end

class ActionDispatch::IntegrationTest
  # Esegue il login vero (POST /session), come farebbe il form. Le fixture usano la password "secret".
  def log_in_as(user, password: "secret")
    post session_path, params: { email: user.email, password: password }
  end
end
