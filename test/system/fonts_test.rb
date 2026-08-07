require "application_system_test_case"

# The other half of story 0009's forcing function.
#
# `test/integration/self_hosted_fonts_test.rb` proves the files are served and
# the third-party hosts are gone. It cannot prove a browser actually rendered in
# them — and neither can `design_test.rb`, despite the story spec claiming it
# does. `getComputedStyle(el).fontFamily` returns the *declared* stack,
# `"Fraunces", "Iowan Old Style", Georgia, serif`, byte for byte identical
# whether Fraunces loaded or the page silently fell back to Georgia.
#
# So the check that matters has to ask the font system, not the cascade.
class FontsTest < ApplicationSystemTestCase
  # `document.fonts` is the CSS Font Loading API: `ready` resolves once the
  # browser has finished loading every face the page actually needs, and
  # `check()` answers whether a given font+size can be rendered from a loaded
  # face rather than a fallback.
  LOADED = <<~JS
    (() => {
      const families = new Set();
      document.fonts.forEach(f => { if (f.status === "loaded") families.add(f.family); });
      return {
        families: [...families].sort(),
        fraunces: document.fonts.check('560 32px Fraunces'),
        newsreader: document.fonts.check('400 16px Newsreader')
      };
    })()
  JS

  def measure
    page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1];
      document.fonts.ready.then(() => done(#{LOADED}));
    JS
  end

  test "the daily page renders in its own typefaces, not in Georgia" do
    visit root_path
    fonts = measure

    assert fonts["fraunces"], "Fraunces did not load — the masthead is in a fallback serif"
    assert fonts["newsreader"], "Newsreader did not load — the body is in a fallback serif"
    assert_equal %w[Fraunces Newsreader], fonts["families"],
      "the page loaded a family that is not one of the two the product has"
  end

  # If this ever fails while the test above passes, the fonts are loading from
  # somewhere — and after story 0009 there is nowhere left but us.
  test "every screen gets both families" do
    [ feed_path, days_path ].each do |path|
      visit path
      fonts = measure

      assert fonts["fraunces"], "#{path} lost Fraunces"
      assert fonts["newsreader"], "#{path} lost Newsreader"
    end
  end
end
