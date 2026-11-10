#!/bin/zsh
# Builds Avro Next.app (arm64) with swiftc + Rust. No Xcode needed, only Command Line Tools.
#   ./build.sh          build + engine test
#   ./build.sh install  also install to ~/Library/Input Methods
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.cargo/bin:$PATH"

ROOT=$PWD
BUILD=$ROOT/build
APP="$BUILD/Avro Next.app"
RITI=$ROOT/riti
ARCH=arm64
MINOS=13.0

if [[ ! -f $RITI/Cargo.toml || ! -d $RITI/data/khipro-classic/.git && ! -f $RITI/data/khipro-classic/.git ]]; then
  echo "The riti engine submodule is missing. Run:"
  echo "  git submodule update --init --recursive"
  exit 1
fi
command -v cargo >/dev/null || { echo "Rust is not installed. Install it from https://rustup.rs"; exit 1; }

echo "==> Building riti (Rust, release)"
(cd "$RITI" && cargo build --release --target aarch64-apple-darwin 2>&1 | tail -2) || \
  (cd "$RITI" && cargo build --release 2>&1 | tail -2)
LIB=$RITI/target/aarch64-apple-darwin/release/libriti.a
[[ -f $LIB ]] || LIB=$RITI/target/release/libriti.a

rm -rf "$BUILD"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/data"

echo "==> Engine test (headless)"
mkdir -p "$BUILD/test" && cp Tests/engine_test.swift "$BUILD/test/main.swift"
swiftc -O -target $ARCH-apple-macos$MINOS -import-objc-header Sources/Bridging-Header.h \
  -Xcc -I"$RITI/include" Sources/Engine.swift Sources/Settings.swift Sources/KeyMap.swift Sources/CandidateState.swift "$BUILD/test/main.swift" \
  "$LIB" -o "$BUILD/engine_test"
"$BUILD/engine_test" "$RITI/data"

echo "==> Building app"
swiftc -O -target $ARCH-apple-macos$MINOS -module-name AvroNext \
  -import-objc-header Sources/Bridging-Header.h -Xcc -I"$RITI/include" \
  Sources/main.swift Sources/Engine.swift Sources/Settings.swift Sources/KeyMap.swift Sources/CandidateState.swift \
  Sources/SettingsWindow.swift Sources/CandidateWindow.swift Sources/AvroController.swift \
  "$LIB" -framework Cocoa -framework InputMethodKit -o "$APP/Contents/MacOS/AvroNext"

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$RITI"/data/{dictionary,suffix,autocorrect,Probhat}.json "$APP/Contents/Resources/data/"
swiftc Tools/make_icon.swift -o "$BUILD/make_icon"
"$BUILD/make_icon" "$APP/Contents/Resources/icon.tiff" "$BUILD/AppIcon.iconset"
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
# Ad-hoc by default. Set SIGN_APP_ID to a "Developer ID Application: ..." identity for distribution.
if [[ -n ${SIGN_APP_ID:-} ]]; then
  # Notarization requires hardened runtime + a secure timestamp.
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_APP_ID" "$APP"
else
  codesign --force --deep --options runtime --sign - "$APP"
fi
plutil -lint "$APP/Contents/Info.plist"
lipo -info "$APP/Contents/MacOS/AvroNext"
# Keep LaunchServices from treating the build output as the installed input method.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" 2>/dev/null || true
echo "==> Built $APP"

if [[ ${1:-} == install ]]; then
  if [[ -d "/Library/Input Methods/Avro Next.app" ]]; then
    echo "Avro Next is installed system-wide by the .pkg. Run ./package.sh and install that instead,"
    echo "so there is only one copy." ; exit 1
  fi
  DEST="$HOME/Library/Input Methods"
  mkdir -p "$DEST"
  pkill -x AvroNext 2>/dev/null || true
  rm -rf "$DEST/Avro Next.app"
  cp -R "$APP" "$DEST/"
  echo "==> Installed to $DEST/Avro Next.app"
  echo "    Log out and back in, then add 'Avro Next' in System Settings > Keyboard > Input Sources > Bengali."
fi
