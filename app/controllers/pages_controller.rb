class PagesController < ApplicationController
  def home
    @latest = Article.visible_to(current_user).latest_first.includes(:categories).with_rich_text_body.with_attached_cover_image.limit(3)
    @articles_count = Article.published.count
  end

  def about
  end
end
