module ApplicationHelper
  MESI = %w[gennaio febbraio marzo aprile maggio giugno luglio agosto
            settembre ottobre novembre dicembre].freeze

  # Nome e slogan del blog: cambiali qui e si aggiornano in tutto il sito.
  def blog_name
    "Fast Break"
  end

  def blog_tagline
    "Il basket raccontato da chi lo ama"
  end

  # "5 ottobre 2026"
  def data_it(time)
    return "" if time.nil?
    "#{time.day} #{MESI[time.month - 1]} #{time.year}"
  end

  # Link della navbar; aggiunge la classe is-active alla pagina corrente.
  def nav_link(text, path, match: nil)
    active = match ? request.path.start_with?(match) : current_page?(path)
    link_to text, path, class: "nav__link#{' is-active' if active}"
  end
end
