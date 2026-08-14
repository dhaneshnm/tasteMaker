require "test_helper"

class PoolSourcesTest < ActiveSupport::TestCase
  # Minneapolis image paths cannot be derived from the object id: the shard
  # comes from `Cache_Location` and the filename from the rendition, not the
  # object. Both halves of this have already shipped a 403 to a reader.
  test "the image path is built from the cache location and the rendition" do
    url = Pool::Sources.mia_image_url(
      { "Cache_Location" => "083000\\600\\40\\83645", "Primary_RenditionNumber" => "mia_5014236.jpg" }, "full"
    )

    assert_equal "https://img.artsmia.org/web_objects_cache/083000/600/40/83645/mia_5014236_full.jpg", url
  end

  # The defect that put "This work is resting" on the front door: a rendition
  # suffix was being stripped, and `mia_3003333_full.jpg` 403s where
  # `mia_3003333_001_full.jpg` is served.
  test "a rendition suffix survives into the filename" do
    record = { "Cache_Location" => "001000\\400\\60\\1463", "Primary_RenditionNumber" => "mia_3003333_001.jpg" }

    assert_equal "https://img.artsmia.org/web_objects_cache/001000/400/60/1463/mia_3003333_001_full.jpg",
      Pool::Sources.mia_image_url(record, "full")
    assert_equal "https://img.artsmia.org/web_objects_cache/001000/400/60/1463/mia_3003333_001_800.jpg",
      Pool::Sources.mia_image_url(record, "800")
  end

  test "a work with no cache location or no rendition has no image" do
    assert_nil Pool::Sources.mia_image_url({ "Primary_RenditionNumber" => "mia_1.jpg" }, "full")
    assert_nil Pool::Sources.mia_image_url({ "Cache_Location" => "001000\\400" }, "full")
    assert_nil Pool::Sources.mia_image_url(
      { "Cache_Location" => "001000\\400", "Primary_RenditionNumber" => "not_a_rendition.jpg" }, "full"
    )
  end

  # Reading a JPEG's size from its header is how the Met's undocumented plate
  # dimensions get checked against the resolution floor without downloading
  # the whole thing.
  test "jpeg dimensions come from the frame header" do
    # SOI, then a minimal SOF0 declaring 1697 x 2048.
    jpeg = [ 0xFF, 0xD8, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x08, 0x00, 0x06, 0xA1 ].pack("C*")

    assert_equal [ 1697, 2048 ], Pool::Sources::Jpeg.dimensions(jpeg)
  end

  test "something that is not a jpeg has no dimensions" do
    assert_equal [ nil, nil ], Pool::Sources::Jpeg.dimensions("<!DOCTYPE html><html>403</html>")
  end
end
