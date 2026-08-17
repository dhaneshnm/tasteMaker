require "application_system_test_case"

# The forcing function for DESIGN.md. One skin is a decision (decisions/0003),
# and a decision without a check is a wish: this fails the moment a screen grows
# its own palette or its own idea of what a picture looks like.
class DesignTest < ApplicationSystemTestCase
  # Second instance of the same vacuity `dynamic_type_test` had. This file
  # compares `/` against `/feed`, `/days` and the 404, and three of those have
  # been behind the wall since story 0015 — so an unauthenticated `visit` landed
  # on the bounce target, which rendered the same partials and satisfied every
  # measurement. It was comparing the front door with itself.
  #
  # Story 0017 retargets that bounce to `/you`, which has no plate, so `fit`
  # came back nil and the comparison finally failed. The bug is older than the
  # change that surfaced it.
  behind_the_wall!

  MEASURED = <<~JS
    (() => {
      const body = getComputedStyle(document.body);
      const img = document.querySelector(".plate__img");
      const brand = getComputedStyle(document.querySelector(".masthead__brand"));
      return {
        paper: body.backgroundColor,
        ink: body.color,
        bodyFont: body.fontFamily,
        brandFont: brand.fontFamily,
        fit: img ? getComputedStyle(img).objectFit : null
      };
    })()
  JS

  test "the daily page and the archive are the same room" do
    visit root_path
    daily = page.evaluate_script(MEASURED)

    visit feed_path
    archive = page.evaluate_script(MEASURED)

    assert_equal daily, archive, "the archive drifted away from the daily page's styling"
    assert_equal "contain", daily["fit"], "an artwork is being cropped"
  end

  # Story 0004. The 404 used to be `public/404.html` — a static file outside the
  # asset pipeline, which is the only reason the one-skin rule never caught it
  # sitting there in system fonts on a white background. Now it is a rendered
  # screen, so it is held to the same bar as every other screen.
  test "the page that isn't there is the same room too" do
    visit root_path
    daily = page.evaluate_script(MEASURED)

    missing = with_rescued_exceptions do
      visit "/nope"
      page.evaluate_script(MEASURED)
    end

    assert_equal daily["paper"], missing["paper"], "the 404 is not on the linen page"
    assert_equal daily["ink"], missing["ink"], "the 404 drifted on ink"
    assert_equal daily["bodyFont"], missing["bodyFont"], "the 404 fell back to a system font"
    assert_equal daily["brandFont"], missing["brandFont"], "the 404's brand drifted"
  end

  test "the paper is the linen page, not the old dark skin" do
    visit root_path

    assert_equal "rgb(244, 239, 230)", page.evaluate_script("getComputedStyle(document.body).backgroundColor")
    assert_equal "rgb(42, 36, 28)", page.evaluate_script("getComputedStyle(document.body).color")
  end
end
