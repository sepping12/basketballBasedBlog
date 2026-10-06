module ArticlesHelper
  def article_date(article)
    data_it(article.published_at || article.created_at)
  end

  def reading_time(article)
    minutes = [(article.body.to_s.split.size / 200.0).ceil, 1].max
    "#{minutes} min di lettura"
  end
end
