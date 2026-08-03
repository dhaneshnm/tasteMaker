require "application_system_test_case"

# The forcing function for DESIGN.md. One skin is a decision (decisions/0003),
# and a decision without a check is a wish: this fails the moment a screen grows
# its own palette or its own idea of what a picture looks like.
class DesignTest < ApplicationSystemTestCase
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

  test "the paper is the linen page, not the old dark skin" do
    visit root_path

    assert_equal "rgb(244, 239, 230)", page.evaluate_script("getComputedStyle(document.body).backgroundColor")
    assert_equal "rgb(42, 36, 28)", page.evaluate_script("getComputedStyle(document.body).color")
  end
end
