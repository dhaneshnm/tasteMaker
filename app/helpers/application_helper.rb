module ApplicationHelper
  # Serve the locally stored copy when we have one, otherwise the museum CDN.
  def artwork_src(painting)
    painting.image.attached? ? url_for(painting.image) : painting.image_url_800
  end
end
