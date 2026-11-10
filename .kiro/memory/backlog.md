# Backlog
- Done: engine wrapper + tests, IMK controller, bundle, build script.
- In Progress: manual verification in real apps on macOS 27 (candidate window preselect, marked text).
- Proposed: settings UI (English suggestions, smart quotes), Fixed/Khipro layouts, proper icon, notarized pkg.
- 2026-11-10 Done: Settings window, Khipro/Probhat layouts, compact row candidate panel, icons, package.sh (dmg+pkg). Unverified: GUI behavior on macOS 27 in real apps.
- 2026-11-10 v0.1.1: input-source registration fixed at TIS level (verified). Still unverified: appears in System Settings picker without Developer ID signing; live typing test.
- 2026-11-10 Done: candidate learning (riti phonetic-candidate-selection.json in ~/Library/Application Support/AvroNext) covered by engine tests: same session, after restart, with trailing punctuation. Live check in apps still pending.
- 2026-11-10 v0.1.2 (Apple Development test-signed) installed. Learning fix pending live confirmation by user.
- 2026-11-10 v0.1.3 CONFIRMED by user on macOS 27: typing, arrow-key candidate selection and remembered choices work (Apple Development test-signed build). Next: Developer ID signing/notarization for distribution.
- 2026-11-10 Published v0.1.3 pre-release via Actions (ad-hoc signed DMG): https://github.com/Shamsulhaq/avro-next/releases/tag/v0.1.3
