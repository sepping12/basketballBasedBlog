require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Blog
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Dominio degli indirizzi email per le bozze (Capitolo 12): <token>@<dominio>.
    # Per ricevere email VERE serve un dominio tuo con un servizio di posta in arrivo; in sviluppo basta questo.
    config.x.drafts_domain = ENV.fetch("DRAFTS_DOMAIN", "drafts.example.com")

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
