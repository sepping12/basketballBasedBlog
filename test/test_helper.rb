ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end

class ActionDispatch::IntegrationTest
  # Esegue il login vero (POST /session), come farebbe il form. Le fixture usano la password "secret".
  def log_in_as(user, password: "secret")
    post session_path, params: { email: user.email, password: password }
  end
end
