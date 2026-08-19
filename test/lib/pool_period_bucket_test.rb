require "test_helper"

# Story 0022 Release 1. Every format below was measured against
# db/seeds/paintings.json's `dated` field — this is not a hypothetical zoo.
class PoolPeriodBucketTest < ActiveSupport::TestCase
  test "a plain year buckets by the strict century convention" do
    assert_equal "20th century", Pool::PeriodBucket.from_dated("1913")
  end

  test "1900 is the 19th century, not the 20th — the strict-convention pin" do
    assert_equal "19th century", Pool::PeriodBucket.from_dated("c. 1900")
  end

  test "a range takes its start year" do
    assert_equal "10th century", Pool::PeriodBucket.from_dated("c. 951–953")
    assert_equal "19th century", Pool::PeriodBucket.from_dated("1837–38")
  end

  test "an explicit century phrase is read directly, prefix words and all" do
    assert_equal "16th century", Pool::PeriodBucket.from_dated("second half 16th century")
    assert_equal "19th century", Pool::PeriodBucket.from_dated("mid 19th century")
    assert_equal "19th century", Pool::PeriodBucket.from_dated("first half of 19th century")
  end

  test "a slash-separated century range takes the start, not whichever ordinal sits next to the word century" do
    assert_equal "16th century", Pool::PeriodBucket.from_dated("16th/17th century")
  end

  test "a round-hundred decade name is a century NICKNAME, one century ahead of its literal year" do
    assert_equal "12th century", Pool::PeriodBucket.from_dated("c. 1100s")
  end

  test "an ordinary decade is NOT the nickname case — it buckets by its start year" do
    assert_equal "19th century", Pool::PeriodBucket.from_dated("Mid–1850s")
    assert_equal "16th century", Pool::PeriodBucket.from_dated("1560s?")
  end

  test "every BCE form maps to nil, never a CE bucket" do
    assert_nil Pool::PeriodBucket.from_dated("11th century BCE")
    assert_nil Pool::PeriodBucket.from_dated("about 1213–1069 BCE")
    assert_nil Pool::PeriodBucket.from_dated("1070–712 BCE")
    assert_nil Pool::PeriodBucket.from_dated("500 B.C.")
    assert_nil Pool::PeriodBucket.from_dated("500 BC")
  end

  test "garbage and blank input are nil, not a guess" do
    assert_nil Pool::PeriodBucket.from_dated("unknown")
    assert_nil Pool::PeriodBucket.from_dated("")
    assert_nil Pool::PeriodBucket.from_dated(nil)
  end
end
