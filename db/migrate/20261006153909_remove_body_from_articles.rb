class RemoveBodyFromArticles < ActiveRecord::Migration[6.0]
  def up
    # Rete di sicurezza: la colonna si toglie SOLO se ogni testo è già stato copiato in Action Text.
    mancanti = select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM articles
      WHERE body IS NOT NULL AND TRIM(body) <> ''
        AND id NOT IN (SELECT record_id FROM action_text_rich_texts WHERE record_type = 'Article' AND name = 'body')
    SQL
    raise "#{mancanti} articoli hanno ancora il testo solo nella colonna body: esegui prima MigrateArticleBodyToActionText" if mancanti > 0

    remove_column :articles, :body
  end

  # Il rollback ricrea la colonna E ci rimette il testo (in testo semplice): il libro la ricrea vuota.
  def down
    add_column :articles, :body, :text
    select_all("SELECT record_id, body FROM action_text_rich_texts WHERE record_type = 'Article' AND name = 'body'").each do |riga|
      testo = ActionController::Base.helpers.strip_tags(riga["body"].to_s.gsub(%r{</p>\s*<p>}, "\n\n").gsub("<br>", "\n"))
      execute "UPDATE articles SET body = #{quote(testo)} WHERE id = #{riga["record_id"].to_i}"
    end
  end
end
