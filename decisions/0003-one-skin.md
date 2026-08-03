# 0003 — One skin: the linen page everywhere

Date: 2026-08-03

Position: the product ships one visual system, "the morning room" — linen paper, ink
type, old gold — on every screen. The archive's near-black "museum at night" skin is
deleted, not kept as a variant. Two skins made moving between the daily pick and the
archive read as two apps, which costs the calm that is one of the two moats we have
(the other is the hand-written voice). The choices and the token table live in
`DESIGN.md`; the full-screen view's dark surround is the one written exception.

Prediction: through the Aug 31, 2026 kill review, no screen — including any premium or
widget surface — will need a second palette or a page-scoped colour override. If one
does, it gets an exception line in `DESIGN.md` with the reason, not a second skin.

Enforcement: `test/system/design_test.rb` fails if the daily page and the archive drift
apart on paper colour, type, or the never-crop rule.
