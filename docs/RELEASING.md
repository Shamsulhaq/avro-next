# Releasing Avro Next

Releases are built and published by GitHub Actions (`.github/workflows/release.yml`) on a GitHub-hosted Apple Silicon Mac. You don't need to upload anything by hand.

## Publish a version

1. Update the version in `Resources/Info.plist` (`CFBundleShortVersionString`, and bump `CFBundleVersion`).
2. Add a section to `CHANGELOG.md`.
3. Commit and push, then tag:

   ```sh
   git tag v0.1.4
   git push origin main v0.1.4
   ```

4. Watch the **Actions** tab. When the run finishes, the DMG and `update.json` are attached to a new Release on the **Releases** page.

The tag must match the version in `Info.plist` (`v0.1.4` for `0.1.4`). The workflow stops if they differ, so installed copies are never offered a mislabeled update.

## How installed copies find updates

Each Release carries an `update.json` with the version, whether it's a pre-release, the DMG link, its SHA-256 and size. Avro Next reads `https://github.com/<repo>/releases.atom` to find the newest tags, then that tag's `update.json`. Neither uses the rate-limited GitHub API. The repository is set by the `AvroNextUpdateRepo` key in `Resources/Info.plist`; change it if you fork the project.

Don't delete or replace a published DMG without also replacing `update.json`. A checksum mismatch makes installed copies refuse the update.

You can also start a build by hand from **Actions > Release > Run workflow**. That build doesn't publish a Release; download the DMG from the run's **Artifacts**.

## Signed vs. unsigned releases

| Repository secrets | Result |
| --- | --- |
| None | Ad-hoc signed DMG, published as a **pre-release**. Users get a Gatekeeper warning, and macOS 27 may not list Avro Next in Input Sources. |
| Developer ID + notarization secrets | Signed, notarized DMG, published as a normal release. Installs without warnings. |

The Developer ID secrets are listed at the top of `release.yml`. To make the `.p12` file:

1. In **Keychain Access**, select both certificates, **Developer ID Application** and **Developer ID Installer**, together with their private keys.
2. Choose **File > Export Items…**, save as `.p12`, and set a password.
3. Run `base64 -i certs.p12 | pbcopy` and paste the result into the `MACOS_CERT_P12_BASE64` secret.

Use an [app-specific password](https://account.apple.com) for `NOTARY_PASSWORD`, never your Apple Account password.

## Building a release locally

```sh
SIGN_APP_ID="Developer ID Application: Your Name (TEAMID)" \
SIGN_PKG_ID="Developer ID Installer: Your Name (TEAMID)" \
NOTARY_PROFILE=avronext \
./package.sh
```
