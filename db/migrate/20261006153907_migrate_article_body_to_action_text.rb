# Sposta il testo degli articli dalla colonna articles.body alla tabella di Action Text.
#
# Il libro lo fa con una sola istruzione SQL (INSERT … SELECT) che copia il testo così com'è. Qui lo faccio in Ruby
# per un motivo: il vecchio testo era TESTO SEMPLICE (i paragrafi si separavano con una riga vuota e l'HTML veniva
# neutralizzato in visualizzazione). Copiato tale e quale in una colonna che contiene HTML, i paragrafi si
# fonderebbero in uno solo e un eventuale "<b>" scritto per caso diventerebbe grassetto. Quindi lo converto.
class MigrateArticleBodyToActionText < ActiveRecord::Migration[6.0]
  def up
    select_all("SELECT id, body, created_at, updated_at FROM articles").each do |riga|
      execute(<<~SQL)
        INSERT INTO action_text_rich_texts (name, body, record_type, record_id, created_at, updated_at)
        VALUES ('body', #{quote(testo_in_html(riga["body"]))}, 'Article', #{riga["id"].to_i},
                #{quote(riga["created_at"])}, #{quote(riga["updated_at"])})
      SQL
    end
  end

  def down
    execute "DELETE FROM action_text_rich_texts WHERE record_type = 'Article' AND name = 'body'"
  end

  private

  # "Primo.\n\nSecondo\nsu due righe" → "<p>Primo.</p><p>Secondo<br>su due righe</p>"  (con l'HTML neutralizzato)
  def testo_in_html(testo)
    testo.to_s.strip.split(/\r?\n[ \t]*\r?\n/).map do |paragrafo|
      "<p>#{ERB::Util.html_escape(paragrafo.strip).gsub(/\r?\n/, "<br>")}</p>"
    end.join
  end
end
