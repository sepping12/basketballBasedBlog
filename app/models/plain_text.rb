# Trasforma testo semplice in HTML per un rich text (Action Text).
#   "Primo.\n\nSecondo\nsu due righe"  →  "<p>Primo.</p><p>Secondo<br>su due righe</p>"
# Una riga vuota separa i paragrafi; un a-capo semplice diventa <br>; l'HTML scritto nel testo viene
# neutralizzato (un "<b>" resta "<b>", non diventa grassetto). Usato dalla mailbox delle bozze e dai dati seme.
module PlainText
  def self.to_html(testo)
    testo.to_s.gsub(/\r\n?/, "\n").strip.split(/\n[ \t]*\n+/).map do |paragrafo|
      "<p>#{ERB::Util.html_escape(paragrafo.strip).gsub("\n", "<br>")}</p>"
    end.join
  end
end
