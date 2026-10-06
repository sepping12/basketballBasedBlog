module ArticlesHelper
  def article_date(article)
    data_it(article.published_at || article.created_at)
  end

  def reading_time(article)
    minutes = [(article.body.to_plain_text.split.size / 200.0).ceil, 1].max
    "#{minutes} min di lettura"
  end

  # "3 commenti" / "1 commento". Usato dalla pagina e dalle risposte Ajax, così il testo è identico.
  def comments_title(article)
    pluralize(article.comments.count, "commento", "commenti")
  end
end
