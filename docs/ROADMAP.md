# Roadmap

| Version | Scope | Status |
|---------|-------|--------|
| 0.1 | Xtream + M3U login, categories, search, favorites, recents, player with auto-reconnect | in progress |
| 0.2 | EPG (XMLTV / Xtream short EPG) with now/next on channels | planned |
| 0.3 | Movies and series (VOD) | planned |
| 0.4 | Android TV build: D-pad focus navigation, leanback manifest, larger layout | planned |
| 0.5 | Multiple accounts UI, picture-in-picture, subtitles/audio track picker | planned |
| 1.0 | Polish, keyboard shortcuts, secure credential storage (Keychain), signed release | planned |

## Open decisions
- Credentials are stored with shared_preferences in 0.1; move to Keychain/secure storage before 1.0.
- Playback uses media_kit (libmpv), chosen for broad codec/container support on IPTV streams.
