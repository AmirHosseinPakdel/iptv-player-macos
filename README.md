# IPTV

A native-feeling IPTV player for **macOS** (Android TV planned), built with Flutter.
Glass-style interface inspired by recent macOS releases, light and dark mode, and
**12 languages** including right-to-left Persian and Arabic.

> **Bring your own streams.** This project is only a player. It ships no channels or
> playlists, and you are responsible for using it with content you are authorized to access.

## Features (v0.1)

- Xtream Codes login (server, username, password) or any M3U / M3U8 playlist URL
- Live TV with categories, instant search, favorites and recently watched
- Playback through `media_kit` (libmpv): wide codec/container support, HLS and MPEG-TS
- Automatic reconnect when a live stream drops
- Fullscreen, volume, previous/next channel, auto-hiding glass controls
- Programme guide (Xtream): what's on now with a progress bar in the channel list, now/next on the player, full upcoming list per channel
- Hide or show the category and channel panels (buttons on the player, or Cmd+1 / Cmd+2)
- Weak-internet mode: bigger buffer, lowest quality, patient retries
- Saved accounts on this Mac
- Languages: English, فارسی, Deutsch, 中文, Español, Français, العربية, Türkçe, Русский,
  Português, Italiano, हिन्दी (or follow the system language)

## Getting started

Requirements: macOS, [Xcode](https://developer.apple.com/xcode/) and [Flutter](https://docs.flutter.dev/get-started/install/macos).

```bash
git clone <your-repo-url> && cd IPTV
./scripts/setup.sh        # generates the macOS runner and patches network settings
flutter run -d macos
```

Tests and static analysis:

```bash
flutter analyze
flutter test
```

## Project layout

```
lib/
  main.dart             app entry, theme, localization setup
  app_state.dart        accounts, channels, favorites, playback and retry logic
  models.dart           Account, Category, Channel, IptvException
  xtream_service.dart   Xtream Codes API client (live TV)
  m3u_parser.dart       M3U / M3U8 parser
  l10n/                 translations (12 languages) and lookup
  screens/              login and home screens
  widgets/              glass panels, player, language picker
test/                   unit tests
docs/ROADMAP.md         what is planned next
```

## Adding or fixing a translation

All UI text lives in `lib/l10n/translations.dart`. Add a language by adding a map there,
a `Locale` in `L10n.supportedLocales` and a name in `L10n.nativeNames`.
Translations should be reviewed by native speakers before a public release.

## Roadmap

See [docs/ROADMAP.md](docs/ROADMAP.md): EPG, movies and series, Android TV (D-pad navigation),
picture-in-picture, secure credential storage.

## License

MIT, see [LICENSE](LICENSE).
