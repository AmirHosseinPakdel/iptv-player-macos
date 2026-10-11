# Android TV plan

The UI is written so that the same code can run on a TV with a remote control.

## Already done (remote-control ready)
- Every control is focusable; the focused item shows a clear highlight (`focusColor`, `FocusRing`).
- D-pad arrows move focus between sidebar, grid and player; OK/Select activates.
- In the player: Left/Right seek (5 s for movies/series, the "skip" setting for live), OK = play/pause,
  Back = leave fullscreen / close the movie / return to the list, Up/Down reach the control bar.
- Media keys: Play/Pause, Fast-forward, Rewind, Next/Previous, Channel up/down.
- Nothing important depends on hover or right-click; long-press (hold OK) opens the hide menu.
- Controls fade out and any key press brings them back.

## Still to do when the TV build starts
1. `flutter create --platforms=android .`
2. In `android/app/src/main/AndroidManifest.xml`:
   - add `<uses-feature android:name="android.hardware.touchscreen" android:required="false"/>`
   - add `<uses-feature android:name="android.software.leanback" android:required="false"/>`
   - add the category `android.intent.category.LEANBACK_LAUNCHER` to the main activity's intent filter
   - add a 320x180 `android:banner`
3. Increase text/ icon sizes for the 10-foot UI (e.g. a `tvMode` flag that scales the theme).
4. Replace `file_picker` for subtitles with a URL field (TVs rarely have a file browser).
5. Test with the Android TV emulator (D-pad only, no mouse).
