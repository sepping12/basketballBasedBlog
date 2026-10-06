class PagesController < ApplicationController
  def home
    @latest = Article.latest_first.includes(:categories).limit(3)
    @articles_count = Article.count
  end

  def about
  end
end
