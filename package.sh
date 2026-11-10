#!/bin/zsh
# Builds dist/Avro-Next-<version>.dmg containing an installer .pkg, an uninstaller and a README.
# Optional env for a smooth install on other Macs (needs a paid Apple Developer account):
#   SIGN_APP_ID="Developer ID Application: Name (TEAMID)"
#   SIGN_PKG_ID="Developer ID Installer: Name (TEAMID)"
#   NOTARY_PROFILE=<keychain profile created with: xcrun notarytool store-credentials>
set -euo pipefail
cd "$(dirname "$0")"
./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
DIST=dist; STAGE=$DIST/stage; PKGROOT=$DIST/pkgroot
rm -rf "$DIST"; mkdir -p "$STAGE" "$PKGROOT" "$DIST/scripts"
export COPYFILE_DISABLE=1
cp -R "build/Avro Next.app" "$PKGROOT/"
xattr -cr "$PKGROOT"

cat > "$DIST/scripts/postinstall" <<'S'
#!/bin/sh
# Stop any running copy so the new version loads on next use.
pkill -x AvroNext 2>/dev/null || true
# Remove a per-user copy from development installs so only one Avro Next exists.
for home in /Users/*; do rm -rf "$home/Library/Input Methods/Avro Next.app" 2>/dev/null; done
# Register the input source so it appears in System Settings without a restart.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "/Library/Input Methods/Avro Next.app" 2>/dev/null || true
exit 0
S
chmod +x "$DIST/scripts/postinstall"

SIGN_ARGS=()
[[ -n ${SIGN_PKG_ID:-} ]] && SIGN_ARGS=(--sign "$SIGN_PKG_ID")
# Never relocate: without this, Installer may "upgrade" a stray copy of the app
# elsewhere on disk (e.g. a build folder) instead of installing to /Library/Input Methods.
pkgbuild --analyze --root "$PKGROOT" "$DIST/components.plist" >/dev/null
# Newer pkgbuild writes the key, older ones omit it: replace it either way.
/usr/libexec/PlistBuddy -c "Delete :0:BundleIsRelocatable" "$DIST/components.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" "$DIST/components.plist"
pkgbuild --root "$PKGROOT" --component-plist "$DIST/components.plist" --identifier org.avronext.inputmethod.AvroNext.pkg --version "$VERSION" \
  --install-location "/Library/Input Methods" --scripts "$DIST/scripts" \
  "$DIST/component.pkg" >/dev/null
productbuild --package "$DIST/component.pkg" "${SIGN_ARGS[@]}" "$STAGE/Install Avro Next.pkg" >/dev/null

# Submits a file to Apple's notary service, fails loudly if it isn't accepted,
# and staples the ticket so Gatekeeper can verify it even offline.
notarize() {
  local file=$1 out id result
  echo "==> Notarizing $(basename "$file") (this can take a few minutes)"
  out=$(xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)
  id=$(print -r -- "$out" | plutil -extract id raw -o - -)
  result=$(print -r -- "$out" | plutil -extract status raw -o - -)
  if [[ $result != Accepted ]]; then
    echo "Notarization of $(basename "$file") ended with status: $result"
    xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" || true
    exit 1
  fi
  xcrun stapler staple "$file"
}
if [[ -n ${NOTARY_PROFILE:-} ]]; then
  [[ -n ${SIGN_APP_ID:-} && -n ${SIGN_PKG_ID:-} ]] || { echo "Notarizing needs SIGN_APP_ID and SIGN_PKG_ID"; exit 1; }
  notarize "$STAGE/Install Avro Next.pkg"
fi

cat > "$STAGE/Uninstall Avro Next.command" <<'S'
#!/bin/zsh
# Removes Avro Next. Asks for your password because the app lives in /Library/Input Methods.
echo "This removes Avro Next from this Mac."
pkill -x AvroNext 2>/dev/null
sudo rm -rf "/Library/Input Methods/Avro Next.app" "$HOME/Library/Input Methods/Avro Next.app"
rm -rf "$HOME/Library/Application Support/AvroNext"
# Pre-rename test builds, if present.
sudo rm -rf "/Library/Input Methods/IavroNext.app" "$HOME/Library/Input Methods/IavroNext.app"
defaults delete org.avronext.inputmethod.AvroNext 2>/dev/null
echo "Done. Log out and back in to finish."
S
chmod +x "$STAGE/Uninstall Avro Next.command"

cat > "$STAGE/READ ME.txt" <<S
Avro Next $VERSION - Bengali (Avro Phonetic, Khipro, Probhat) typing for Apple Silicon Macs

INSTALL
1. Double-click "Install Avro Next.pkg" and follow the steps.
   If macOS blocks it ("can't be opened" / "not verified"): click Done, then open
   System Settings > Privacy & Security, scroll down, click "Open Anyway"
   next to Install Avro Next.pkg, and enter your password.
2. Log out and log back in.
3. System Settings > Keyboard > Input Sources > Edit... > "+" > Bengali > Avro Next > Add.
4. Switch input source from the menu bar (or Ctrl+Space) and type.

SETTINGS
Menu bar input icon > "Avro Next Settings...", or open Avro Next from /Library/Input Methods.

UNINSTALL
Double-click "Uninstall Avro Next.command".

Typing engine: OpenBangla riti (MPL-2.0), https://github.com/OpenBangla/riti
S

DMG=$DIST/Avro-Next-$VERSION.dmg
hdiutil create -quiet -volname "Avro Next" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
[[ -n ${SIGN_APP_ID:-} ]] && codesign --force --timestamp --sign "$SIGN_APP_ID" "$DMG"

[[ -n ${NOTARY_PROFILE:-} ]] && notarize "$DMG"
# Remove the staging copy so LaunchServices never launches it instead of the installed one.
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
$LSR -u "$PWD/$PKGROOT/Avro Next.app" 2>/dev/null || true
rm -rf "$PKGROOT" "$DIST/component.pkg" "$DIST/components.plist" "$DIST/scripts"
echo "==> $DMG"
ls -lh "$DMG"
