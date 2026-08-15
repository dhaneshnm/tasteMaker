require "test_helper"

class FavoriteTest < ActiveSupport::TestCase
  DIGEST = Digest::SHA256.hexdigest("a-reader")

  test "a reader keeps a work once, however many times they ask" do
    Favorite.create!(collector_digest: DIGEST, painting: paintings(:harbour))

    duplicate = Favorite.new(collector_digest: DIGEST, painting: paintings(:harbour))

    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordNotUnique) do
      # The validation is the polite half; the index is the half that holds when
      # two requests race past the read.
      duplicate.save(validate: false)
    end
  end

  test "two readers can keep the same work" do
    Favorite.create!(collector_digest: DIGEST, painting: paintings(:sunflowers))

    assert_equal 2, Favorite.where(painting: paintings(:sunflowers)).count
  end

  test "a favorite belongs to somebody" do
    assert_not Favorite.new(painting: paintings(:harbour)).valid?
  end

  test "collected_by finds one reader's rows and nobody else's" do
    mine = Favorite.create!(collector_digest: DIGEST, painting: paintings(:harbour))

    assert_equal [ mine ], Favorite.collected_by(DIGEST).to_a
    # Subsumed by the line above, kept for the failure message: this is the
    # model-level guard for the privacy property the digest column exists for,
    # and a leak should name the reader whose row leaked rather than dumping two
    # arrays at whoever broke it.
    assert_not_includes Favorite.collected_by(DIGEST), favorites(:strangers_sunflowers),
      "collected_by leaked another reader's row"
  end

  # The whole point of the digest column: a database copy is not a set of
  # credentials.
  test "the stored identity is a digest, not anything a cookie could carry" do
    assert_match(/\A[0-9a-f]{64}\z/, favorites(:strangers_sunflowers).collector_digest)
  end

  # db/seeds.rb only ever upserts by (source, source_id), so this cannot happen today. Asserted
  # so that a future cleanup task discovers the constraint here rather than in
  # production, and has to decide what happens to the collections holding the work.
  test "a painting somebody kept cannot be deleted out from under them" do
    Favorite.create!(collector_digest: DIGEST, painting: paintings(:harbour))

    assert_raises(ActiveRecord::InvalidForeignKey) { paintings(:harbour).delete }
  end

  # The two keys (story 0015): exactly one identity per row, never both,
  # never neither.
  test "a row carries exactly one identity" do
    user = User.create!(provider: "google_oauth2", uid: "u1")

    assert Favorite.new(user: user, painting: paintings(:harbour)).valid?
    assert Favorite.new(collector_digest: DIGEST, painting: paintings(:harbour)).valid?
    assert_not Favorite.new(painting: paintings(:harbour)).valid?
    assert_not Favorite.new(user: user, collector_digest: DIGEST,
      painting: paintings(:harbour)).valid?
  end

  test "a user keeps a work once, and the index holds under a race" do
    user = User.create!(provider: "google_oauth2", uid: "u1")
    Favorite.create!(user: user, painting: paintings(:harbour))

    duplicate = Favorite.new(user: user, painting: paintings(:harbour))

    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save(validate: false) }
  end

  test "owned_by and collected_by are disjoint worlds" do
    user = User.create!(provider: "google_oauth2", uid: "u1")
    theirs = Favorite.create!(user: user, painting: paintings(:harbour))
    mine = Favorite.create!(collector_digest: DIGEST, painting: paintings(:harbour))

    assert_equal [ theirs ], Favorite.owned_by(user).to_a
    assert_not_includes Favorite.collected_by(DIGEST), theirs
    assert_not_includes Favorite.owned_by(user), mine
  end
end
