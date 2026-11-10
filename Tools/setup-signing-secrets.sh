#!/bin/zsh
# One-time setup: uploads Developer ID signing and notarization secrets to the
# GitHub repository, so the Release workflow builds signed, notarized installers.
#
# Before running:
#   1. Your Apple Developer Program membership is active.
#   2. "Developer ID Application" and "Developer ID Installer" certificates are in
#      your login keychain (see docs/RELEASING.md).
#   3. You exported both to one .p12 file from Keychain Access.
#   4. You created an app-specific password at https://account.apple.com.
#   5. `gh auth status` shows you're logged in.
#
# Run it yourself in Terminal:  ./Tools/setup-signing-secrets.sh
# Secrets you type are never shown or written to disk. They go straight to
# `gh secret set` (encrypted by GitHub) and to your keychain for local builds.
set -euo pipefail
cd "$(dirname "$0")/.."

die() { print -u2 -- "Error: $*"; exit 1; }

command -v gh >/dev/null || die "GitHub CLI (gh) isn't installed."
gh auth status >/dev/null 2>&1 || die "Run 'gh auth login' first."
REPO=${REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}
echo "Repository: $REPO"

# 1. Find the two Developer ID identities.
app_id=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"$/\1/p' | head -1)
pkg_id=$(security find-identity -v | sed -n 's/.*"\(Developer ID Installer: .*\)"$/\1/p' | head -1)
[[ -n $app_id ]] || die "No 'Developer ID Application' certificate in your keychain. See docs/RELEASING.md."
[[ -n $pkg_id ]] || die "No 'Developer ID Installer' certificate in your keychain. See docs/RELEASING.md."
team=${app_id##*\(}; team=${team%\)}
[[ ${pkg_id##*\(} == "$team)" ]] || die "The two certificates belong to different teams."
echo "Found:  $app_id"
echo "        $pkg_id"
echo "Team ID: $team"
echo

# 2. The exported .p12 with both certificates and their private keys.
read -r "p12?Path to the exported .p12 file: "
p12=${p12/#\~/$HOME}
p12=${p12//\\ / }
[[ -f $p12 ]] || die "File not found: $p12"
read -rs "p12_password?Password of that .p12: "; echo
subjects=$(P12PASS=$p12_password openssl pkcs12 -in "$p12" -nokeys -passin env:P12PASS 2>/dev/null | grep -i "subject" || true)
if [[ -z $subjects ]]; then
  echo "Note: couldn't read the .p12 to double-check it (wrong password, or a format this openssl can't read)."
  read -r "go?Upload it anyway? [y/N] "; [[ $go == [yY] ]] || exit 1
else
  [[ $subjects == *"Developer ID Application"* ]] || die "The .p12 doesn't contain the Developer ID Application certificate."
  [[ $subjects == *"Developer ID Installer"* ]] || die "The .p12 doesn't contain the Developer ID Installer certificate."
  echo "The .p12 contains both certificates."
fi

# 3. Notarization login. store-credentials checks it with Apple and saves a
#    local profile named "avronext" for signed builds on this Mac too.
read -r "apple_id?Apple Account email: "
read -rs "app_password?App-specific password (xxxx-xxxx-xxxx-xxxx): "; echo
echo "Checking the notarization login with Apple…"
xcrun notarytool store-credentials avronext --apple-id "$apple_id" --team-id "$team" --password "$app_password" >/dev/null \
  || die "Apple rejected the notarization login. Check the email, the app-specific password and the team."
echo "Notarization login works (also saved locally as keychain profile 'avronext')."

# 4. Upload to GitHub. Values are piped over stdin, never passed as arguments.
put() { print -rn -- "$2" | gh secret set "$1" -R "$REPO" >/dev/null && echo "  set $1"; }
echo "Uploading secrets to $REPO:"
base64 -i "$p12" | gh secret set MACOS_CERT_P12_BASE64 -R "$REPO" >/dev/null && echo "  set MACOS_CERT_P12_BASE64"
put MACOS_CERT_PASSWORD "$p12_password"
put SIGN_APP_ID "$app_id"
put SIGN_PKG_ID "$pkg_id"
put NOTARY_APPLE_ID "$apple_id"
put NOTARY_TEAM_ID "$team"
put NOTARY_PASSWORD "$app_password"
unset p12_password app_password

echo
echo "Done. The next tag you push builds a signed, notarized release:"
echo "  bump the version in Resources/Info.plist, then"
echo "  git tag vX.Y.Z && git push origin main vX.Y.Z"
echo
echo "You can now delete the .p12 file: $p12"
