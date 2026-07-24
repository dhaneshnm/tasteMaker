class PaintingsController < ApplicationController
  PER_PAGE = 10

  def index
    @page = params.fetch(:page, 1).to_i.clamp(1, 10_000)
    offset = (@page - 1) * PER_PAGE
    @paintings = Painting.with_attached_image.feed_ordered.offset(offset).limit(PER_PAGE)
    @next_page = @page + 1 if Painting.count > offset + PER_PAGE
    @total = Painting.count
  end
end
