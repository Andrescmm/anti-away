# AntiAway release and update process

This document maps the complete macOS release process: build, Developer ID
signing, Apple notarization, DMG packaging, GitHub Release publication,
Sparkle activation, and landing-page synchronization.

## System overview

```text
Swift source
    ↓
Developer ID signed .app
    ↓
Apple notarizes the app
    ↓
Signed and notarized DMG
    ↓
GitHub Release hosts the DMG
    ↓
appcast.xml announces the release
    ↓
Sparkle verifies and installs the update

Landing page ──────────→ serves the same notarized DMG
```

The two repositories have different responsibilities:

| Repository | Responsibility |
| --- | --- |
| `Andrescmm/anti-away` | Swift source, Sparkle feed, release scripts, and GitHub Releases |
| `Andrescmm/anti-away-landing` | Public website and a copy of the latest DMG for new installations |

New users download the app from the landing page. Existing installations use
Sparkle and the GitHub Release asset.

## One-time configuration

The project is already configured with:

- Sparkle 2.9.6.
- `SUFeedURL` pointing to the public `appcast.xml` on GitHub.
- `SUPublicEDKey` containing the public Sparkle verification key.
- Developer ID signing for Fizz Software S.A.C.
- Hardened Runtime.
- The `AntiAwayNotary` Keychain profile for Apple notarization.
- The private Sparkle EdDSA key in the login Keychain under the `ed25519`
  account.

The update feed is:

```text
https://raw.githubusercontent.com/Andrescmm/anti-away/main/appcast.xml
```

The private EdDSA key must never be committed. Keep a secure backup outside
the repository. The application only contains the corresponding public key.

## Version numbers

Every release must increment both target settings:

```text
MARKETING_VERSION = 1.2.1
CURRENT_PROJECT_VERSION = 7
```

- `MARKETING_VERSION` is the user-facing version.
- `CURRENT_PROJECT_VERSION` is the monotonically increasing build number that
  Sparkle uses to decide whether an update is newer.

Never reuse a build number. For example, after `1.2.0 (6)`, use at least
`1.2.1 (7)`.

## Release checklist

Run the following steps from the `anti-away` repository root. The commands use
`1.2.1` and build `7` as an example; replace the version for the actual
release.

### 1. Finish and test the source release

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the AntiAway
   target.
2. Run the unit tests.
3. Commit and push the source before building the release.

```sh
git add AntiAway.xcodeproj AntiAway AntiAwayTests README.md docs
git commit -m "Prepare AntiAway 1.2.1"
git push origin main
```

Confirm the working tree is clean:

```sh
git status
```

### 2. Create the Developer ID archive

```sh
xcodebuild \
  -project AntiAway.xcodeproj \
  -scheme AntiAway \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/AntiAway-1.2.1.xcarchive \
  archive \
  DEVELOPMENT_TEAM=9XV8H38HB4 \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='Developer ID Application: Fizz Software S.A.C (9XV8H38HB4)' \
  PROVISIONING_PROFILE_SPECIFIER=''
```

The archive must end with `** ARCHIVE SUCCEEDED **`.

### 3. Export the signed application

```sh
xcodebuild \
  -exportArchive \
  -archivePath build/AntiAway-1.2.1.xcarchive \
  -exportPath build/export-1.2.1 \
  -exportOptionsPlist ExportOptions.plist
```

The exported application is:

```text
build/export-1.2.1/AntiAway.app
```

Validate its version, signature, and Sparkle runpath:

```sh
/usr/libexec/PlistBuddy \
  -c 'Print :CFBundleShortVersionString' \
  build/export-1.2.1/AntiAway.app/Contents/Info.plist

/usr/libexec/PlistBuddy \
  -c 'Print :CFBundleVersion' \
  build/export-1.2.1/AntiAway.app/Contents/Info.plist

codesign --verify --deep --strict --verbose=2 \
  build/export-1.2.1/AntiAway.app

otool -l build/export-1.2.1/AntiAway.app/Contents/MacOS/AntiAway \
  | grep -A2 LC_RPATH
```

The output must include `@executable_path/../Frameworks`; Sparkle will not load
without that runpath.

### 4. Notarize and staple the application

```sh
ditto -c -k --keepParent \
  build/export-1.2.1/AntiAway.app \
  build/AntiAway-1.2.1.zip

xcrun notarytool submit \
  build/AntiAway-1.2.1.zip \
  --keychain-profile AntiAwayNotary \
  --wait
```

Continue only when Apple returns `status: Accepted`.

```sh
xcrun stapler staple build/export-1.2.1/AntiAway.app
xcrun stapler validate build/export-1.2.1/AntiAway.app
```

### 5. Create and notarize the DMG

The packaging script copies the app, adds the Applications shortcut, creates
and signs the DMG, submits the exact DMG to Apple, and staples the accepted
ticket.

```sh
NOTARY_PROFILE=AntiAwayNotary \
./scripts/package_dmg.sh \
  build/export-1.2.1/AntiAway.app \
  build/AntiAway-1.2.1.dmg
```

Validate the final artifact:

```sh
xcrun stapler validate build/AntiAway-1.2.1.dmg
spctl -a -t open --context context:primary-signature \
  -v build/AntiAway-1.2.1.dmg
shasum -a 256 build/AntiAway-1.2.1.dmg
```

Gatekeeper must report `accepted` and `source=Notarized Developer ID`.

### 6. Write release notes

Create a Markdown file that describes user-visible changes:

```text
build/AntiAway-1.2.1.md
```

Sparkle embeds these notes in the appcast and GitHub uses the same file for
the Release page.

### 7. Generate the signed Sparkle appcast

```sh
./scripts/generate_appcast.sh \
  1.2.1 \
  build/AntiAway-1.2.1.dmg \
  build/AntiAway-1.2.1.md
```

This script:

1. Copies the DMG to `build/sparkle-updates/AntiAway-1.2.1.dmg`.
2. Reads the private EdDSA key from Keychain.
3. Signs the update for Sparkle.
4. Detects version, build, architectures, and minimum macOS version.
5. Embeds the release notes.
6. Updates the local `appcast.xml`.

At this point, do **not** commit `appcast.xml` yet.

### 8. Publish the GitHub Release first

Confirm GitHub CLI authentication:

```sh
gh auth status
```

Create the release and upload the versioned update archive:

```sh
gh release create v1.2.1 \
  build/sparkle-updates/AntiAway-1.2.1.dmg \
  --repo Andrescmm/anti-away \
  --title "AntiAway 1.2.1" \
  --notes-file build/AntiAway-1.2.1.md
```

Verify the release and download URL:

```sh
gh release view v1.2.1 \
  --repo Andrescmm/anti-away \
  --json url,tagName,isDraft,isPrerelease,assets

curl -fIL \
  https://github.com/Andrescmm/anti-away/releases/download/v1.2.1/AntiAway-1.2.1.dmg
```

The URL must eventually return HTTP 200 after GitHub's redirect.

### 9. Activate the update by publishing the appcast

Only after the release asset is publicly downloadable:

```sh
git add appcast.xml
git commit -m "Publish AntiAway 1.2.1 update"
git push origin main
```

Verify the public feed:

```sh
curl -fsSL \
  'https://raw.githubusercontent.com/Andrescmm/anti-away/main/appcast.xml?release=1.2.1' \
  | grep -E '1.2.1|sparkle:version|enclosure|edSignature'
```

Publishing the appcast is the activation point. Existing installations can
discover the update as soon as the new entry is publicly served.

The order is critical:

```text
GitHub Release first → appcast.xml second
```

Publishing the appcast first would advertise an update whose download URL may
still return 404.

### 10. Update the landing repository

The landing is a separate repository at:

```text
/Users/andres/Documents/anti-away-landing
```

Copy the exact notarized DMG without renaming the public route:

```sh
cp \
  /Users/andres/Documents/anti-away/build/AntiAway-1.2.1.dmg \
  /Users/andres/Documents/anti-away-landing/public/downloads/AntiAway.dmg
```

Update both English and Spanish version labels in `app/page.tsx`, then verify
that the two DMGs are identical:

```sh
shasum -a 256 \
  /Users/andres/Documents/anti-away/build/AntiAway-1.2.1.dmg \
  /Users/andres/Documents/anti-away-landing/public/downloads/AntiAway.dmg
```

Run the landing tests and publish it:

```sh
cd /Users/andres/Documents/anti-away-landing
npm test
git add app/page.tsx public/downloads/AntiAway.dmg
git commit -m "Publish AntiAway 1.2.1 download"
git push origin main
```

## How an installed app updates

```text
AntiAway reads appcast.xml
        ↓
Sparkle compares sparkle:version with CFBundleVersion
        ↓
Sparkle downloads the GitHub Release DMG
        ↓
The EdDSA signature is verified with SUPublicEDKey
        ↓
The Developer ID signature and notarization remain intact
        ↓
Sparkle replaces AntiAway.app and relaunches it
```

Users may enable automatic checks or select **Check for Updates…** manually.
Update checks occur while AntiAway is running.

Settings normally persist because they live in `UserDefaults`, and macOS
normally preserves Accessibility authorization because the bundle identifier,
path, and Developer ID signing identity remain stable.

Do not change these release identity values without planning a migration:

```text
Bundle identifier: com.fizzsoftware.AntiAway
Team ID: 9XV8H38HB4
Signing identity: Developer ID Application: Fizz Software S.A.C
```

## Security layers

Every release uses three independent protections:

1. **Sparkle EdDSA signature** — proves that the update was signed with the
   AntiAway update key.
2. **Developer ID signature** — identifies Fizz Software S.A.C as the macOS
   developer.
3. **Apple notarization** — confirms that Apple processed and accepted the
   submitted app and DMG.

If the DMG changes after the appcast is generated, its length and EdDSA
signature become invalid. Regenerate the appcast whenever the release artifact
changes.

## Failure and recovery rules

- If notarization fails, inspect the submission log and do not publish the
  artifact.
- If the GitHub Release upload fails, do not commit the new appcast.
- If the DMG changes, regenerate the appcast before publication.
- Never replace a published DMG silently. Publish a new version and build
  number instead.
- Keep old GitHub Release assets and appcast entries available so older clients
  retain an upgrade path.
- If an incorrect appcast is published, immediately restore the previous valid
  feed or publish a corrected feed whose asset already exists.
- Never commit the private EdDSA key, Apple credentials, app-specific
  passwords, certificates with private keys, or notarization secrets.

## Compact checklist

```text
[ ] Implement and test changes
[ ] Increment MARKETING_VERSION
[ ] Increment CURRENT_PROJECT_VERSION
[ ] Commit and push source
[ ] Create Developer ID archive
[ ] Export signed app
[ ] Notarize and staple app
[ ] Create, notarize, and staple DMG
[ ] Write release notes
[ ] Generate signed appcast
[ ] Create GitHub Release and upload DMG
[ ] Verify public DMG URL
[ ] Commit and push appcast.xml
[ ] Replace landing DMG
[ ] Update landing version text
[ ] Run landing tests
[ ] Commit and push landing
[ ] Test Check for Updates from an older installed version
```
