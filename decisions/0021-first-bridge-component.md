# 0020 — The shell's first bridge component

Date: 2026-08-31. Context: story 0031 (`specs/0031-out-the-door/`), owner scoping
session, one question at a time.

## Position

The share button (story 0031) is built as a Hotwire Native **bridge component** —
the first one in the shell — not as a Web Share API call from the web layer.

The stack rule says "bridge components only where genuinely required." This one is:
the feature is *share the full-resolution image file into the iOS share sheet*, and
file-bearing `navigator.share` inside WKWebView is unverified territory, while
`UIActivityViewController` is the platform's guaranteed answer. Owner weighed a
device spike on the Web Share API first and rejected it (2026-08-31): the spike's
best outcome merely matches what the bridge already promises, and its failure mode
is discovering mid-story that the native half is needed anyway.

No server-side version gate accompanies it. Old binaries never register the `share`
component, so the bridge handshake itself hides the button — `shell_version_at_least?`
gains no new caller.

## Prediction (falsifiable, time-bound)

Same as story 0031's success signal: within 14 days of the 1.2 binary reaching
readers, the production log shows ≥ 10 requests carrying `via=share`. Zero in 14
days = the button is furniture and the "genuinely required" bar was cleared for a
feature nobody uses — say so in the next kill/keep note.

Secondary: the bridge machinery (JS pin + one Swift component) stays this size. If a
second bridge component appears without its own decisions entry arguing necessity,
this entry is the precedent to cite against it, not for it.
