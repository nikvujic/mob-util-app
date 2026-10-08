# Versioning & releases

## Version numbers

The version lives in one place, `pubspec.yaml`:

```yaml
version: 0.2.0+2
#        │ │ │ └─ build number (Android versionCode): +1 on every release
#        │ │ └─── patch: bug fixes only
#        │ └───── minor: new features or visible changes
#        └─────── major: 0 until the planned feature set is complete → 1.0.0
```

Android only installs an update over an existing app if the build number is
higher, so it goes up by one on **every** release.

Every roadmap step that changes the app is a release. Docs-only or CI-only
changes are not released on their own.

## Making a release

1. Bump `version` in `pubspec.yaml`.
2. Add a section to `CHANGELOG.md`: `## [X.Y.Z] - YYYY-MM-DD` with
   *Added* / *Changed* / *Fixed* lists, written for the user.
3. Commit (`Release vX.Y.Z`) and push to `main`.
4. Start the release, either way:
   - **On GitHub** (works from the phone too): *Actions → Release → Run
     workflow* on `main`. It releases the version in `pubspec.yaml` and
     creates the `vX.Y.Z` tag; it refuses if that version is already
     released.
   - **Or push a tag**: `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin
     vX.Y.Z` (the tag must match `pubspec.yaml`).
5. The **Release** workflow runs the tests, builds the APK signed with the
   release key, and publishes a GitHub Release with the APK and the
   changelog section as notes.

To install: open the release on the phone and download the APK (allow
installing from the browser once).

## Signing key (one-time setup)

Every release must be signed with the **same** key — Android refuses to
update an app signed with a different key, and the only way out is to
uninstall, which deletes the app's data. So the key is created once, kept
safe, and given to GitHub as secrets.

1. Create the key (needs a JDK; Android Studio ships one):

   ```sh
   keytool -genkeypair -v -keystore the-app-release.jks \
     -alias the-app -keyalg RSA -keysize 4096 -validity 36500
   ```

   Pick a strong password; use the same one for the key when asked.

2. **Back it up** (password manager / encrypted drive) together with the
   password. Losing it means future versions can't be installed over the
   current one. Never commit it — `*.jks` and `key.properties` are ignored.

3. Add four repository secrets on GitHub
   (*Settings → Secrets and variables → Actions → New repository secret*):

   | Secret | Value |
   |--------|-------|
   | `ANDROID_KEYSTORE_BASE64` | output of `base64 -w0 the-app-release.jks` (macOS: `base64 -i the-app-release.jks`; Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("the-app-release.jks"))`) |
   | `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
   | `ANDROID_KEY_ALIAS` | `the-app` |
   | `ANDROID_KEY_PASSWORD` | the key password |

### Signed builds on your PC (optional)

Copy the `.jks` into `android/app/` and create `android/key.properties`:

```properties
storeFile=the-app-release.jks
storePassword=…
keyAlias=the-app
keyPassword=…
```

`flutter build apk --release` then produces an APK signed with the release
key. Without `key.properties`, release builds use the debug key (fine for
trying things out, but such an APK can't be updated by a real release).
