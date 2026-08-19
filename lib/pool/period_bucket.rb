# Turns a museum's free-text `dated` field into a century bucket a reader can
# filter by (story 0022 Release 1). Two failure modes, and only one is safe:
# unparseable text returns nil — the work simply never matches a period
# filter, safe. A BCE date's start-year grabbed and labeled a CE century
# would be an ACTIVELY WRONG label on a rendered facet, which is worse than
# no label at all — so BCE maps to nil too, deliberately, checked first.
#
# Century arithmetic is the strict convention: `((year - 1) / 100) + 1`, so
# 1900 is the 19th century and 1901 opens the 20th — "c. 1900" reads
# colloquially as 20th, and that is exactly the trap this pins against.
#
# A DIFFERENT rule applies to a "NN00s" DECADE NAMED AS A CENTURY — "the
# 1100s" is common English for "the 12th century," not literally the years
# 1100-1109. That is genuinely a different number from the strict year
# formula (the YEAR 1100 is 11th century; the ERA NICKNAME "1100s" is 12th),
# and collapsing the two is the off-by-one trap eng review measured against
# this pool's manifest. An ordinary decade ("1850s", "1560s?") is not this
# case — only a round-hundred decade name is a century nickname, so those
# fall through to the plain-year rule instead.
module Pool
  module PeriodBucket
    BCE = /\bBCE\b|\bBC\b|B\.C\.E\.|B\.C\./i
    CENTURY_WORD = /century/i
    ORDINAL_TOKEN = /(\d{1,2})(?:st|nd|rd|th)/i
    HUNDREDS_DECADE_NICKNAME = /\b(\d{2,3})00s\b/i
    ANY_YEAR = /\d{3,4}/

    # A bucket only makes sense in this range — a stray 3-digit number that
    # isn't actually a year (an accession number fragment, say) shouldn't
    # mint a nonsense century.
    VALID_CENTURIES = (1..21)

    # Returns the canonical display value ("16th century") or nil.
    def self.from_dated(string)
      text = string.to_s
      return nil if text.blank? || text.match?(BCE)

      century = century_for(text)
      return nil unless century && VALID_CENTURIES.cover?(century)

      "#{century.ordinalize} century"
    end

    def self.century_for(text)
      # Explicit "Nth century" wins outright, and takes the FIRST ordinal
      # token in the string — "16th/17th century" and "second half 16th
      # century" both want the start of the range, not whichever ordinal
      # happens to sit next to the word "century".
      if text.match?(CENTURY_WORD) && (m = text.match(ORDINAL_TOKEN))
        return m[1].to_i
      end

      # The century-nickname decade, checked before a plain year so "1100s"
      # doesn't fall through to the wrong rule.
      if (m = text.match(HUNDREDS_DECADE_NICKNAME))
        return m[1].to_i + 1
      end

      # Any other 3-4 digit number: a plain year, or the start of a range
      # ("1837–38" → 1837, "c. 951–953" → 951) — the leftmost number in the
      # string is always the range's start in this pool's formats.
      if (m = text.match(ANY_YEAR))
        return century_from_year(m[0].to_i)
      end

      nil
    end

    def self.century_from_year(year)
      ((year - 1) / 100) + 1
    end
  end
end
