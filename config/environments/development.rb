Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Segnala gli errori di consegna delle email (nel libro è false: nasconderebbe i problemi SMTP).
  config.action_mailer.raise_delivery_errors = true

  # I link nelle email (article_url…) hanno bisogno di sapere l'indirizzo del sito.
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

  # Server SMTP: i dati stanno nelle credentials cifrate (config/credentials.yml.enc), mai in chiaro qui.
  # Se sono ancora i segnaposto "CAMBIA…", NON si invia nulla: le email si salvano come file in tmp/mails
  # (e si vedono comunque in anteprima su http://localhost:3000/rails/mailers).
  smtp = Rails.application.credentials.smtp
  if smtp && !smtp[:user_name].to_s.include?("CAMBIA")
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: smtp[:address], port: smtp[:port], enable_starttls_auto: true, authentication: :plain,
      user_name: smtp[:user_name], password: smtp[:password]
    }
  else
    config.action_mailer.delivery_method = :file
    config.action_mailer.file_settings = { location: Rails.root.join("tmp/mails") }
  end

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations.
  # config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
end
