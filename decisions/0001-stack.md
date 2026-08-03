# 0001 — Stack: Rails-native path, web-first iOS

Date: 2026-08-03

Position: Rails 8.x omakase (Propshaft, importmaps, Hotwire), SQLite + Solid trifecta,
Kamal 2 + Thruster, Minitest — fastest full-stack path for a solo Rails-fluent dev
building a content app; one codebase serves web + iOS via Hotwire Native; deployment,
jobs, cache, and websockets all stay first-party Rails. One accepted native exception:
APNs push registration and delivery, because daily push is the core habit mechanic.

Prediction: through the Aug 31, 2026 kill review, no requirement will force leaving this
path except APNs push (already excepted); if one does, it gets its own decision file.
