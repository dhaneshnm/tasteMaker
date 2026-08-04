module ApplicationHelper
  # Where a painting's picture comes from: the locally stored copy when we have
  # one, otherwise the museum CDN. One rule, one place.
  #
  # `size:` asks for a square-bounded variant instead of the full image — the
  # archive list draws thumbnails, and an 800px JPEG at 112px, thirty times, is
  # about 20 MB on a phone.
  #
  # The rescue is narrow and it logs. It catches the blob refusing to be varied at
  # all (wrong content type, missing blob); actual vips failures happen later,
  # when the variant is resolved, and surface as a broken image, which the row's
  # collapsed thumbnail already handles. A bare rescue plus a working fallback
  # would let a wholly broken pipeline look healthy while quietly serving
  # full-size images forever.
  def artwork_src(painting, size: nil)
    return painting.image_url_800 unless painting.image.attached?
    return url_for(painting.image) if size.nil? || !resizing_available?

    painting.image.variant(resize_to_limit: [ size, size ])
  rescue ActiveStorage::Error => e
    Rails.logger.warn("[artwork_src] variant failed for painting #{painting.id}: #{e.class}")
    painting.image_url_800
  end

  # Resizing needs libvips or ImageMagick on the box, and this machine has
  # neither — see the analyzer note in `config/application.rb`. Asking for a
  # variant anyway does not raise here: it raises later, inside Active Storage's
  # redirect controller, so every thumbnail 500s and the rescue above never sees
  # it. Ask whether resizing is possible before requesting it.
  def resizing_available?
    ActiveStorage.variant_transformer.present?
  end
end
