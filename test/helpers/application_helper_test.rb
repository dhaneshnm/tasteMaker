require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  PIXEL = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")

  setup { @painting = paintings(:sunflowers) }

  test "a painting with no local copy falls back to the museum CDN" do
    assert_not @painting.image.attached?

    assert_equal @painting.image_url_800, artwork_src(@painting)
    assert_equal @painting.image_url_800, artwork_src(@painting, size: 240)
  end

  # The regression guard: this call feeds the plate on the daily page, the
  # archive and the zoom overlay. Adding `size:` must not change it.
  test "a local copy with no size asked for is served whole" do
    attach(content_type: "image/png")

    assert_not_kind_of ActiveStorage::Variant, artwork_src(@painting)
    assert_match @painting.image.filename.to_s, artwork_src(@painting)
  end

  test "a size asks for a bounded variant where resizing is available" do
    attach
    variant = with_resizing { artwork_src(@painting, size: 240) }

    assert_equal [ 240, 240 ], variant.variation.transformations[:resize_to_limit]
    assert_equal @painting.image.blob, variant.blob
  end

  # No libvips on this box. Asking for a variant anyway does not fail here — it
  # fails inside Active Storage's redirect controller, so every thumbnail 500s
  # and the row's fallback never gets a chance. Serve the whole image instead.
  test "with no image processor on the box, the whole image is served" do
    attach
    assert_not resizing_available?

    assert_not_kind_of ActiveStorage::VariantWithRecord, artwork_src(@painting, size: 240)
    assert_match @painting.image.filename.to_s, artwork_src(@painting, size: 240)
  end

  # A blob that cannot be varied at all — a file that is not really an image.
  # The archive must not 500 over one bad row.
  test "a blob that refuses to be varied logs once and falls back" do
    attach(bytes: "this is not a painting", filename: "notes.txt", content_type: "text/plain")
    logged = capture_log { with_resizing { @result = artwork_src(@painting, size: 240) } }

    assert_equal @painting.image_url_800, @result
    assert_match "[artwork_src] variant failed", logged
    assert_match @painting.id.to_s, logged
  end

  private
    def attach(bytes: PIXEL, filename: "pixel.png", content_type: "image/png")
      @painting.image.attach(io: StringIO.new(bytes), filename: filename, content_type: content_type)
    end

    # Stands in for a box that has libvips. The helper only asks whether a
    # transformer exists, never calls it, so the class itself does not matter.
    def with_resizing
      original = ActiveStorage.variant_transformer
      ActiveStorage.variant_transformer = ActiveStorage::Transformers::ImageProcessingTransformer
      yield
    ensure
      ActiveStorage.variant_transformer = original
    end

    def capture_log
      original = Rails.logger
      sink = StringIO.new
      Rails.logger = ActiveSupport::Logger.new(sink)
      yield
      sink.string
    ensure
      Rails.logger = original
    end
end
