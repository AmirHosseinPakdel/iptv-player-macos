# Updates without an app store

The app updates itself from this repository's **GitHub Releases**. Users never visit a store.

## How a user experiences it
- On start (and every 6 hours) the app asks GitHub for the latest release. Nothing is sent about the user.
- **Small fix** (only the last number changes, e.g. 0.1.0 → 0.1.1): downloaded quietly in the background and
  installed the next time the app starts. The window restarts once, within a second or two. No dialog.
- **Bigger update** (middle or first number changes, e.g. 0.1.x → 0.2.0): a dialog shows "What's new" with
  **Update and restart**, **Later** and **Skip this version**.
- **Mandatory update**: put `<!-- mandatory -->` anywhere in the release notes. The dialog cannot be dismissed
  and the update is never skipped or silent.
- Settings → General → *App updates*: current version, "Check for updates", and the mode
  (small fixes silently / always ask / never check).

## How you publish an update
1. Change the code, commit and push to `main`.
2. Create a tag and push it:
   ```
   git tag v0.1.1
   git push origin v0.1.1
   ```
3. GitHub Actions (`.github/workflows/release.yml`) builds the app, zips it, writes a SHA-256 file and
   publishes the release. The version number comes from the tag.
4. Optional: edit the release notes on GitHub (shown to users in the dialog).

Version rule of thumb: `0.1.1` = quiet fix, `0.2.0` = visible update with notes.

## Safety
- The download is verified against the published SHA-256 before it is installed.
- If the app cannot replace itself (for example it lives where the user has no write permission), it opens the
  new version in Finder instead.
- A failed quiet update is never retried in a loop; the old version keeps working.
- Debug builds (`flutter run`) never install anything.

## Things to know (macOS)
- The updater swaps the app bundle, so the app is **not sandboxed** (`app-sandbox` is `false` in the entitlements).
  That is normal for apps distributed outside the Mac App Store.
- Without an Apple Developer ID the very first install from a browser download shows the macOS warning
  "cannot verify the developer": the user opens it once with right-click → Open. Updates done by the app itself
  do not trigger the warning again. Signing and notarizing (99 USD/year) removes the first-install warning.
- Updates come from a public repository. Anyone who can push a tag to it can ship code to all users,
  so keep your GitHub account protected with two-factor authentication.

## Later: Android TV
Same release page, an extra `*-android.apk` asset; the app downloads it and hands it to the Android package
installer (needs the "install unknown apps" permission). On Google Play, the store updates it instead.

## Ideas for changes without any new release
Text, defaults and feature switches can be controlled from a small JSON file in this repo that the app reads
(remote config). Not built yet.
