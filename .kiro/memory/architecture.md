# Architecture
- `riti/` (OpenBangla/riti, MPL-2.0, git clone, gitignored build output): Rust engine, built to `libriti.a` (arm64) with C API `riti/include/riti.h`.
- `Sources/`: Swift InputMethodKit app. `Engine.swift` wraps the C API; `KeyMap.swift` char -> riti keycode; `AvroController.swift` is the IMKInputController (marked text + IMKCandidates); `main.swift` starts IMKServer.
- `build.sh`: swiftc + cargo, no Xcode needed. Runs `Tests/engine_test.swift` headless, builds `build/Avro Next.app`, ad-hoc signs. `./build.sh install` copies to ~/Library/Input Methods.
- Bundle id `org.avronext.inputmethod.AvroNext`, mode `...Phonetic`, language bn. Product name: Avro Next (renamed from iAvro Next on 2026-11-10; workspace folder still `iavro`).
- Dictionary/autocorrect/suffix JSON copied to app Resources/data; learned selections go to ~/Library/Application Support/AvroNext.
