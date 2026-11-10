# Avro Next

Avro Phonetic Bengali (Bangla) typing for Apple Silicon Macs, built for macOS 27.

The original iAvro is Intel-only and stopped working on newer macOS. Avro Next is a new, native arm64 input method written from scratch in Swift. It uses the [OpenBangla riti](https://github.com/OpenBangla/riti) engine for the typing rules and the dictionary, so it doesn't need Rosetta.

## Features

- **Avro Phonetic** typing (`ami` → `আমি`), plus the **Khipro** and **Probhat** layouts
- **Dictionary suggestions** in a compact candidate bar, like iAvro's
- **Remembers your choices:** pick a different word once and it becomes the default for that word
- **Auto-correct** with your own entries, plus optional smart quotes and English words in suggestions
- **Live settings:** changes apply immediately, with no restart

## Requirements

- A Mac with Apple Silicon (M1 or later)
- macOS 13 or later (tested on macOS 27.2)

## Install

1. Download the latest `Avro-Next-<version>.dmg` from [Releases](../../releases) and open it.
2. Double-click **Install Avro Next.pkg** and follow the steps.
3. Log out and log back in.
4. Open **System Settings > Keyboard > Input Sources > Edit…**, click **+**, choose **Bengali**, select **Avro Next**, and click **Add**.
5. Pick Avro Next from the input menu in the menu bar, or press the 🌐 key, and start typing.

If macOS says the installer "can't be opened" or isn't verified, click **Done**. Then open **System Settings > Privacy & Security**, scroll down, click **Open Anyway** next to the installer, and enter your password.

> **Note on signing:** on macOS 27, an input method with no real code signature installs but may not appear in the Input Sources list. Release builds need to be signed with a Developer ID for that reason. If you build it yourself, see [Build from source](#build-from-source).

## Typing

| Key | Action |
| --- | --- |
| Space, Return, Tab | Commit the highlighted word |
| ← → or ↑ ↓ | Move between suggestions |
| Page Up / Page Down | Jump through suggestions |
| Click a word | Commit that word |
| Esc | Cancel the current word |
| Backspace | Delete one letter (Ctrl or Option + Backspace deletes the whole word) |

## Settings

Open the input menu in the menu bar and choose **Avro Next Settings…**.

- **Layout:** Avro Phonetic, Khipro or Probhat (Fixed)
- **Suggestions:** dictionary suggestions, English words, smart quotes
- **Probhat options:** automatic vowel forming, chandrabindu, kar joining, reph style, numpad digits, kar order
- **Candidate window:** compact row or list, and font size
- **Data:** edit auto-correct, forget learned words, restore defaults

Your learned choices and auto-correct entries are stored in `~/Library/Application Support/AvroNext/`.

## Troubleshooting

**Avro Next isn't in the Input Sources list**
- Log out and back in after installing. macOS only loads new input methods at login.
- Make sure the app is in `/Library/Input Methods/Avro Next.app`.
- On macOS 27 an input method without a real code signature may be hidden from the list. Use a signed release, or sign your own build (see [Build from source](#build-from-source)).

**Typing gives plain English letters**
- Avro Next isn't the active input source. Pick it from the input menu in the menu bar, or press the 🌐 key.

**The installer "can't be opened"**
- Open **System Settings > Privacy & Security**, scroll down, and click **Open Anyway** next to the installer.

**It picks the wrong word for something I type often**
- Type the word, choose the right one with the arrow keys, and press Space. Avro Next remembers that choice.
- To clear all remembered choices, use **Settings > Forget Learned…**.

**Settings changes don't take effect**
- They apply immediately for the next word you type. If something looks stuck, switch to another input source and back.

**Still stuck?** [Open an issue](../../issues) with your macOS version and what you did.

## Uninstall

Double-click **Uninstall Avro Next.command** in the DMG. Then log out and back in.

## Build from source

You need the Xcode Command Line Tools (`xcode-select --install`) and [Rust](https://rustup.rs). Full Xcode isn't required.

```sh
git clone --recurse-submodules https://github.com/Shamsulhaq/avro-next.git
cd avro-next
./build.sh          # builds build/Avro Next.app and runs the engine tests
./package.sh        # builds dist/Avro-Next-<version>.dmg with the installer
```

Sign the build so macOS lists it in Input Sources. A free Apple Development certificate is enough for your own Mac:

```sh
security find-identity -v -p codesigning     # find your identity
SIGN_APP_ID="Apple Development: you@example.com (XXXXXXXXXX)" ./package.sh
```

To make a release other people can install without warnings, use Developer ID certificates and notarization. This needs a paid Apple Developer membership:

```sh
SIGN_APP_ID="Developer ID Application: Your Name (TEAMID)" \
SIGN_PKG_ID="Developer ID Installer: Your Name (TEAMID)" \
NOTARY_PROFILE=<profile from: xcrun notarytool store-credentials> \
./package.sh
```

Maintainers: releases are built and published automatically by GitHub Actions when you push a version tag. See [docs/RELEASING.md](docs/RELEASING.md). Version history is in [CHANGELOG.md](CHANGELOG.md).

## Project layout

```text
Sources/      Swift input method: controller, candidate bar, settings, riti wrapper
Resources/    Info.plist
Tests/        Headless engine and selection tests (run by build.sh)
Tools/        Icon generator and an input-source diagnostic (tis_check.swift)
riti/         OpenBangla riti engine (git submodule)
docs/         Release guide
.github/      Release workflow (build, package, publish on tag)
build.sh      Build + test
package.sh    DMG with installer, uninstaller and read-me
```

## Credits and license

- Typing engine: [OpenBangla riti](https://github.com/OpenBangla/riti) by Muhammad Mominul Huque and contributors (MPL-2.0)
- Avro Phonetic was created by [OmicronLab](https://omicronlab.com). Avro Next is an independent project, not affiliated with OmicronLab.

Avro Next is released under the [Mozilla Public License 2.0](LICENSE).
