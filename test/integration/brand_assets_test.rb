require "test_helper"
require "json"

# The forcing function for `script/brand-render`.
#
# The mark is drawn once in `brand/*.svg` and every shipped raster is generated
# from those files. Sixteen generated files that nothing checks are sixteen
# files that drift the first time the mark is nudged — which is the whole reason
# R1 exists.
#
# What this CANNOT be is a re-render and a diff. `script/brand-render` needs
# Chrome and macOS `sips`; CI runs Rails on ubuntu, and macOS and Linux do not
# rasterise identically anyway — `launch.svg` contains real type, so the bytes
# differ every run for legitimate reasons. So the check is structural instead:
#
#   1. every file the asset catalogue names exists, at the pixel size it claims
#   2. every web icon exists, at the size the manifest and <head> claim
#   3. the SHA of every source SVG still matches what the last render recorded
#
# (3) is the one that catches the sneaky failure: a PNG of exactly the right
# size, built from a drawing that has since moved.
class BrandAssetsTest < ActiveSupport::TestCase
  ICONSET = Rails.root.join("ios/Tondo/Assets.xcassets/AppIcon.appiconset")
  MANIFEST = Rails.root.join("brand/manifest.json")

  # PNG header: width and height are big-endian 32-bit ints at bytes 16..23.
  # Read directly rather than shelling out to `sips`, so this passes on Linux CI.
  def png_dimensions(path)
    header = File.binread(path, 24)
    assert_equal "\x89PNG".b, header[0, 4], "#{path} is not a PNG"
    header[16, 8].unpack("N2")
  end

  test "every icon the catalogue names exists at the size it claims" do
    entries = JSON.parse(ICONSET.join("Contents.json").read).fetch("images")
    assert_operator entries.size, :>=, 9, "the icon set lost entries"

    entries.each do |entry|
      file = ICONSET.join(entry.fetch("filename"))
      assert file.exist?, "#{entry['filename']} is named in Contents.json but not on disk"

      # "60x60" at "3x" is 180 real pixels. The marketing entry is 1x.
      points = entry.fetch("size").split("x").first.to_f
      scale = entry.fetch("scale", "1x").to_i
      expected = (points * scale).round

      width, height = png_dimensions(file)
      assert_equal [ expected, expected ], [ width, height ],
        "#{entry['filename']} is #{width}x#{height} but its slot wants #{expected}x#{expected}"
    end
  end

  test "no orphaned icons sit in the catalogue directory" do
    named = JSON.parse(ICONSET.join("Contents.json").read)
      .fetch("images").map { |i| i["filename"] }.compact.uniq
    on_disk = Dir.glob(ICONSET.join("*.png")).map { |p| File.basename(p) }

    assert_empty on_disk - named,
      "PNGs in the icon set that no slot references — Xcode ignores these silently"
  end

  # A tinted appearance on a legacy per-size entry builds green and is dropped:
  # Xcode reports "unassigned children" as a warning and ships an icon with no
  # tinted rendition. The appearance belongs on the universal single-size slot.
  test "the tinted appearance sits on the universal slot, where Xcode will use it" do
    entries = JSON.parse(ICONSET.join("Contents.json").read).fetch("images")
    tinted = entries.select { |e| e["appearances"].present? }

    assert_equal 1, tinted.size, "expected exactly one tinted entry"
    assert_equal "universal", tinted.first["idiom"]
    assert_equal "1024x1024", tinted.first["size"]
    assert_equal [ { "appearance" => "luminosity", "value" => "tinted" } ],
      tinted.first["appearances"]
  end

  test "the web icons exist at the sizes the head and the manifest declare" do
    {
      "public/icon.png" => 512,          # PWA purpose: any
      "public/icon-maskable.png" => 640, # PWA purpose: maskable, padded for the crop
      "public/apple-touch-icon.png" => 180
    }.each do |path, expected|
      file = Rails.root.join(path)
      assert file.exist?, "#{path} is missing — run script/brand-render"

      width, height = png_dimensions(file)
      assert_equal [ expected, expected ], [ width, height ],
        "#{path} is #{width}x#{height}, expected #{expected}x#{expected}"
    end

    assert Rails.root.join("public/icon.svg").exist?,
      "public/icon.svg is missing — it is the favicon, and the only version sharp at 16px"
  end

  test "the rendered assets were built from the current sources" do
    assert MANIFEST.exist?, "brand/manifest.json is missing — run script/brand-render"

    recorded = JSON.parse(MANIFEST.read).fetch("sources")
    assert recorded.any?, "the manifest records no sources"

    stale = recorded.reject { |path, sha|
      file = Rails.root.join(path)
      file.exist? && Digest::SHA256.hexdigest(file.read) == sha
    }

    assert_empty stale.keys,
      "these sources changed without a re-render:\n  #{stale.keys.join("\n  ")}\n" \
      "Run: script/brand-render"
  end
end
