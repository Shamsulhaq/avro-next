# Contributing to Avro Next

Thanks for helping. Avro Next is a small, friendly project, and contributions of any size are welcome: bug reports, testing on your Mac, documentation, translations of the docs, and code.

## Ways to help

- **Report a bug:** [open an issue](https://github.com/Shamsulhaq/avro-next/issues/new?template=bug_report.md) with your macOS version, Avro Next version, the app you were typing in, what you typed, and what happened.
- **Suggest an idea:** [open a feature request](https://github.com/Shamsulhaq/avro-next/issues/new?template=feature_request.md).
- **Wrong word or spelling:** if Avro Phonetic gives a wrong suggestion, say what you typed and what you expected. Dictionary and phonetic rules come from the [riti](https://github.com/OpenBangla/riti) engine, so some fixes belong there. We'll help route it.
- **Test a release:** pre-releases are on the [Releases](https://github.com/Shamsulhaq/avro-next/releases) page. Reports from macOS 27 and from apps like Word, Chrome and Slack are especially useful.
- **Pick up an issue:** look for the `good first issue` and `help wanted` labels. Comment on the issue first so work isn't duplicated.

## Development setup

You need an Apple Silicon Mac, the Xcode Command Line Tools and Rust. Full Xcode isn't required.

```sh
xcode-select --install                      # Command Line Tools
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh   # Rust

git clone --recurse-submodules https://github.com/Shamsulhaq/avro-next.git
cd avro-next
./build.sh                                  # builds the app and runs the tests
```

If you cloned without `--recurse-submodules`, run `git submodule update --init --recursive`.

### Trying your build

macOS only lists input methods with a real code signature in Input Sources. A free Apple Development certificate is enough for your own Mac. You get one by signing in with your Apple Account in Xcode, or from your developer account.

```sh
security find-identity -v -p codesigning    # find your identity
SIGN_APP_ID="Apple Development: you@example.com (XXXXXXXXXX)" ./package.sh
open "dist/stage/Install Avro Next.pkg"
```

Then log out and back in, and add Avro Next in **System Settings > Keyboard > Input Sources**. After a reinstall, switching to another input source and back usually loads the new version. If it doesn't, log out and in.

To see how macOS sees the installed input method:

```sh
swiftc Tools/tis_check.swift -framework Carbon -o build/tis_check && build/tis_check
```

## How the code is organised

| File | What it does |
| --- | --- |
| `Sources/main.swift` | Starts the InputMethodKit server and the update checker |
| `Sources/AvroController.swift` | Key handling, composition (marked text), committing words |
| `Sources/CandidateState.swift` | The candidate list and which one is chosen (single source of truth) |
| `Sources/CandidateWindow.swift` | The compact candidate bar (display only, never takes focus) |
| `Sources/Engine.swift` | Swift wrapper around the riti C API |
| `Sources/KeyMap.swift` | Typed character → riti key code |
| `Sources/Settings.swift`, `SettingsWindow.swift` | Preferences and the Settings window |
| `Sources/UpdateCore.swift`, `UpdateManager.swift` | Update check (testable core) and the notification/installer UI |
| `Tests/engine_test.swift` | Headless tests, run by `build.sh` |
| `riti/` | OpenBangla riti engine (git submodule, Rust) |

Two rules that keep the typing stable:

- **`CandidateState` owns the selection.** The candidate bar only displays it. Letting a window decide the selection caused the "doesn't remember my choice" bug in 0.1.2.
- **Keep the engine path testable.** Logic that doesn't need AppKit goes in a plain Swift file the tests can compile, like `UpdateCore.swift`.

## Making a change

1. Fork the repository and create a branch: `git checkout -b fix-short-description`.
2. Make the change. Match the existing style: small types, clear names, comments that explain *why*.
3. Add or update a test in `Tests/engine_test.swift` for any behaviour change or bug fix.
4. Run `./build.sh`. It must end with `ALL PASSED` and build without warnings.
5. If you changed typing or the candidate bar, try it in at least one real app (Notes or TextEdit).
6. Add a line to `CHANGELOG.md` under an "Unreleased" heading.
7. Open a pull request and fill in the template. CI builds and tests every pull request automatically.

Keep pull requests focused on one change. Small ones get reviewed faster.

## Changes to riti

The phonetic rules, dictionary and suggestions come from [OpenBangla/riti](https://github.com/OpenBangla/riti). Changes to the engine itself should go to that project first, so all its users benefit. Once merged upstream, we update the submodule here.

## Releases

Only the maintainer publishes releases. See [docs/RELEASING.md](docs/RELEASING.md).

## Code of conduct

Be kind and patient. Everyone is welcome here, whatever their experience, background or language. Disagree about ideas, not people. Harassment or personal attacks aren't tolerated, and the maintainer may remove comments or block accounts that cross that line. To report a problem privately, contact the maintainer through [shamsul.me](http://shamsul.me).

## License

By contributing, you agree that your contributions are licensed under the [Mozilla Public License 2.0](LICENSE), the same license as the project.
