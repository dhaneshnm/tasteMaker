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
  # and the row's fallback never gets a chance.
  #
  # Regression: ISSUE-001 — the fallback served the locally stored ORIGINAL for a
  # 112px box (640-755 KB each, measured on /days), which is the 20 MB phone page
  # the size argument exists to prevent. The museum's 800px copy is ~112 KB.
  # Found by /qa on 2026-08-04.
  # Report: .gstack/qa-reports/qa-report-localhost-2026-08-04.md
  test "with no image processor on the box, a thumbnail takes the smaller CDN copy" do
    attach
    assert_not resizing_available?

    assert_equal @painting.image_url_800, artwork_src(@painting, size: 240)
  end

  test "with no image processor and no CDN copy, the local original is the only option" do
    @painting.update!(image_url_800: nil)
    attach

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

  # Story 0031. The regression this guards against has a name: the first
  # draft of this helper built the link from a published day's own page,
  # which sits behind `require_reader` (only `daily#show` skips the wall) —
  # a shared link would have bounced every recipient to sign-in instead of
  # showing them art (eng review E1). `root_url`, never anything else, no
  # matter what the painting's own day situation is.
  test "the share link is always root, for a painting with a published day" do
    assert_equal @painting, daily_picks(:today).painting

    assert_equal root_url(via: "share"), share_payload_for(@painting)[:url]
  end

  test "the share link is always root, for a painting with no day at all" do
    never_picked = paintings(:woodcut)
    assert_not DailyPick.exists?(painting_id: never_picked.id)

    assert_equal root_url(via: "share"), share_payload_for(never_picked)[:url]
  end

  test "the share text is the painting's own title-and-artist string" do
    assert_equal @painting.alt_text, share_payload_for(@painting)[:text]
  end

  # `alt_text` already carries story 0018's placeholder-artist fallback
  # (`artist_display`) — asserted here so a future change to either method
  # can't drift the share text away from what the page itself says.
  test "the share text falls back the same way the wall label does, for a placeholder artist" do
    culture_only = paintings(:bronze)

    assert_equal "Bronze Ritual Vessel — Chinese", share_payload_for(culture_only)[:text]
  end

  # Outside voice C4/C1: `url_for(painting.image)` raises for a painting
  # that only has `display_image?` satisfied via the museum CDN fallback —
  # exactly `@painting` (`sunflowers`), which every other test in this file
  # already keeps unattached on purpose.
  test "the share image follows the CDN fallback when there is no local copy" do
    assert_not @painting.image.attached?

    assert_equal @painting.image_url_800, share_payload_for(@painting)[:image_path]
  end

  test "the share image is the original attached blob when there is one" do
    attach

    assert_match @painting.image.filename.to_s, share_payload_for(@painting)[:image_path]
  end

  # Story 0033. The house voice, whoever wrote the day's words.
  test "the pinned comment speaks as Tondo on a hand-written day" do
    pick = daily_picks(:today)
    assert pick.hand_written?

    assert_equal "Tondo", pinned_voice(pick, @painting)
    assert_equal "T", pinned_voice_initial("Tondo")
  end

  # Every `Painting::SOURCES` name opens with "the"/"The" — initialing it
  # raw would put "T" in every museum's medallion too, indistinguishable
  # from Tondo's own. The initial has to skip past the article.
  test "the pinned comment speaks as the museum on a fallback day, initialed past the article" do
    pick = daily_picks(:today)
    pick.update!(blurb: "")
    assert_not pick.hand_written?
    @painting.update!(source: "cma")

    assert_equal "the Cleveland Museum of Art", pinned_voice(pick, @painting)
    assert_equal "C", pinned_voice_initial("the Cleveland Museum of Art")
  end

  test "the museum initial still resolves for a source whose article is capitalized" do
    pick = daily_picks(:today)
    pick.update!(blurb: "")
    @painting.update!(source: "met")

    assert_equal "The Metropolitan Museum of Art", pinned_voice(pick, @painting)
    assert_equal "M", pinned_voice_initial("The Metropolitan Museum of Art")
  end

  # A blank voice can only reach here by bypassing validation (a stray
  # `update_column`, a bad import row) — this renders on every front door,
  # so it must degrade for one bad row, never 500 the whole page.
  test "the medallion never raises on a blank voice" do
    assert_equal "?", pinned_voice_initial("")
    assert_equal "?", pinned_voice_initial(nil)
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
