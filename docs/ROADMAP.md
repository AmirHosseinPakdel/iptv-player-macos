# Roadmap

| Version | Scope | Status |
|---------|-------|--------|
| 0.1 | Xtream + M3U login, categories, search, favorites, recents, player with auto-reconnect | in progress |
| 0.2 | EPG: Xtream short EPG with now/next on channels (done), XMLTV for M3U playlists (planned) | in progress |
| 0.3 | Movies and series (VOD) | planned |
| 0.4 | Android TV build: D-pad focus navigation, leanback manifest, larger layout | planned |
| 0.5 | Multiple accounts UI, picture-in-picture, subtitles/audio track picker | planned |
| 1.0 | Polish, keyboard shortcuts, secure credential storage (Keychain), signed release | planned |

## Open decisions
- Credentials are stored with shared_preferences in 0.1; move to Keychain/secure storage before 1.0.
- Playback uses media_kit (libmpv), chosen for broad codec/container support on IPTV streams.

## Startup page (done)
Settings → "Open at startup": last used page, or Live / Movies / Series with All, Favorites or Recently watched,
or the page that is open right now ("Use current page", works for a single category too).
Falls back to a sensible page when the choice is not available. Optional: play the last channel on start.

## In-app updates (done)
Checks GitHub Releases, quiet installs for small fixes, a one-click dialog for bigger ones. See [UPDATES.md](UPDATES.md).
