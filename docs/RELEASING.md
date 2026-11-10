# Releasing Avro Next

Releases are built and published by GitHub Actions (`.github/workflows/release.yml`) on a GitHub-hosted Apple Silicon Mac. You don't upload anything by hand.

## Publish a version

1. Update the version in `Resources/Info.plist` (`CFBundleShortVersionString`, and bump `CFBundleVersion`).
2. Add a section to `CHANGELOG.md`.
3. Commit, push and tag:

   ```sh
   git tag v0.1.5
   git push origin main v0.1.5
   ```

4. Watch the **Actions** tab. When the run finishes, the DMG and `update.json` are attached to a new Release on the **Releases** page.

The tag must match the version in `Info.plist` (`v0.1.5` for `0.1.5`). The workflow stops if they differ, so installed copies are never offered a mislabeled update.

## Signed vs. unsigned releases

| Repository secrets | Result |
| --- | --- |
| None | Ad-hoc signed DMG, published as a **pre-release**. macOS says it "could not verify" the installer, and on macOS 27 Avro Next may not appear in Input Sources. |
| Developer ID + notarization (below) | Signed and notarized, published as a normal release. Installs with no warning and appears in Input Sources. |

## One-time setup: Developer ID signing

### 1. Join the Apple Developer Program

Enroll as an **Individual** at [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll). There's a yearly fee. Use your legal name on your Apple Account; a nickname delays approval. Approval takes from a few hours to a few days.

### 2. Create a certificate request (no Xcode needed)

1. Open **Keychain Access**.
2. Choose **Keychain Access > Certificate Assistant > Request a Certificate From a Certificate Authority…**.
3. Enter your email and name, choose **Saved to disk**, and save the `.certSigningRequest` file.

### 3. Create the two Developer ID certificates

1. Go to [Certificates, IDs & Profiles](https://developer.apple.com/account/resources/certificates/list) and click **+**.
2. Choose **Developer ID Application**, upload the request file, and download the certificate.
3. Click **+** again, choose **Developer ID Installer**, upload the same request file, and download it.
4. Double-click both downloaded `.cer` files to add them to your login keychain.

Check that they're installed:

```sh
security find-identity -v | grep "Developer ID"
```

You should see one **Developer ID Application** line and one **Developer ID Installer** line.

### 4. Export both certificates to one .p12 file

1. In **Keychain Access**, select the **login** keychain and the **My Certificates** tab.
2. Command-click to select both **Developer ID Application: …** and **Developer ID Installer: …**.
3. Choose **File > Export Items…**, pick **Personal Information Exchange (.p12)**, and save it, for example to the Desktop.
4. Set a strong password for the file. You'll type it once in step 6.

### 5. Create an app-specific password

Sign in at [account.apple.com](https://account.apple.com), open **Sign-In and Security > App-Specific Passwords**, and create one named "Avro Next notarization". Copy it (it looks like `xxxx-xxxx-xxxx-xxxx`). Never use your normal Apple Account password here.

### 6. Upload the secrets

In Terminal, from the project folder:

```sh
./Tools/setup-signing-secrets.sh
```

The script:

- finds both certificates in your keychain and reads your Team ID from them
- asks for the `.p12` path and password, and checks the file has both certificates
- asks for your Apple Account email and the app-specific password, and checks them with Apple
- uploads seven encrypted secrets to the GitHub repository: `MACOS_CERT_P12_BASE64`, `MACOS_CERT_PASSWORD`, `SIGN_APP_ID`, `SIGN_PKG_ID`, `NOTARY_APPLE_ID`, `NOTARY_TEAM_ID`, `NOTARY_PASSWORD`
- saves a local notarization profile named `avronext`, for signed builds on your own Mac

What you type isn't shown, logged or written to disk. Delete the `.p12` file afterwards.

To review or change secrets later, open the repository's **Settings > Secrets and variables > Actions**.

### 7. Release

Bump the version and push a tag as in [Publish a version](#publish-a-version). The workflow signs the app, signs the installer, notarizes the installer and the DMG with Apple, staples the tickets, and publishes a normal (not pre-release) Release. Notarization usually adds a few minutes.

If notarization is rejected, the run fails and its log includes Apple's report explaining why.

## Signed builds on your own Mac

After step 6 the `avronext` profile is in your keychain:

```sh
SIGN_APP_ID="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"$/\1/p' | head -1)" \
SIGN_PKG_ID="$(security find-identity -v | sed -n 's/.*"\(Developer ID Installer: .*\)"$/\1/p' | head -1)" \
NOTARY_PROFILE=avronext \
./package.sh
```

## How installed copies find updates

Each Release carries an `update.json` with the version, whether it's a pre-release, the DMG link, its SHA-256 and size. Avro Next reads `https://github.com/<repo>/releases.atom` to find the newest tags, then that tag's `update.json`. Neither uses the rate-limited GitHub API. The repository is set by the `AvroNextUpdateRepo` key in `Resources/Info.plist`; change it if you fork the project.

Copies signed with a Developer ID only accept an update whose installer is signed by the same team.

Don't delete or replace a published DMG without also replacing `update.json`. A checksum mismatch makes installed copies refuse the update.

## Certificate renewal

Developer ID certificates last five years. When one is renewed, repeat steps 4 and 6. Builds already notarized keep working.
