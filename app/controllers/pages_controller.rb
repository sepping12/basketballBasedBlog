class PagesController < ApplicationController
  def home
    @latest = Article.latest_first.includes(:categories).with_attached_cover_image.limit(3)
    @articles_count = Article.count
  end

  def about
  end
end
