class PagesController < ApplicationController
  def home
    @latest = Article.recent.limit(3)
    @articles_count = Article.count
  end

  def about
  end
end
