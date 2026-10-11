import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../updater.dart';
import 'glass.dart';
import 'update_dialog.dart';
import 'tracks_dialog.dart' show SubtitleColorPicker;

/// Settings window: tabs on the left, grouped rows on the right.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

enum _Tab { general, playback, subtitles, accounts }

class _SettingsDialogState extends State<SettingsDialog> {
  _Tab _tab = _Tab.general;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    final tabs = <(_Tab, IconData, String)>[
      (_Tab.general, Icons.tune_rounded, l.tabGeneral),
      (_Tab.playback, Icons.play_circle_rounded, l.tabPlayback),
      (_Tab.subtitles, Icons.subtitles_rounded, l.subtitles),
      (_Tab.accounts, Icons.person_rounded, l.tabAccounts),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 600),
        child: Glass(
          radius: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 200,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
                        child: Text(l.settings,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      for (final t in tabs)
                        _TabItem(
                          icon: t.$2,
                          label: t.$3,
                          selected: _tab == t.$1,
                          onTap: () => setState(() => _tab = t.$1),
                        ),
                    ],
                  ),
                ),
              ),
              VerticalDivider(
                  width: 1, color: scheme.onSurface.withValues(alpha: 0.1)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: switch (_tab) {
                          _Tab.general => const _GeneralTab(),
                          _Tab.playback => const _PlaybackTab(),
                          _Tab.subtitles => const _SubtitlesTab(),
                          _Tab.accounts => const _AccountsTab(),
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l.done),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontSize: 13.5)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A rounded group of rows with an optional title above it.
class _Group extends StatelessWidget {
  const _Group({this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Text(title!,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant)),
            ),
          Container(
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        indent: 14,
                        endIndent: 14,
                        color: scheme.onSurface.withValues(alpha: 0.08)),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Title (+ explanation) on the left, the control on the right.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.subtitle,
    this.trailing,
    this.below,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!,
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 14),
                trailing!,
              ],
            ],
          ),
          if (below != null) ...[const SizedBox(height: 10), below!],
        ],
      ),
    );
  }
}

Widget _switch(bool value, ValueChanged<bool> onChanged) =>
    Switch(value: value, onChanged: onChanged);

Widget _seconds(List<int> values, int current, ValueChanged<int> onChanged,
    {bool enabled = true}) {
  return SegmentedButton<int>(
    showSelectedIcon: false,
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
    segments: [for (final v in values) ButtonSegment(value: v, label: Text('$v s'))],
    selected: {current},
    onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
  );
}

// ---------------------------------------------------------------- General

class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Group(
          title: l.language,
          children: [
            _Row(
              title: l.language,
              trailing: DropdownButton<String>(
                value: app.locale?.languageCode ?? '_system',
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                      value: '_system', child: Text(l.systemDefault)),
                  for (final e in L10n.nativeNames.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  app.setLocale(v == '_system' ? null : Locale(v));
                },
              ),
            ),
          ],
        ),
        _Group(
          title: l.startupPage,
          children: [
            _Row(
              title: l.startupPage,
              subtitle: l.descStartup,
              below: const _StartupPicker(),
            ),
            _Row(
              title: l.autoPlayLast,
              trailing: _switch(app.autoPlayLast, app.setAutoPlayLast),
            ),
            _Row(
              title: l.useCurrentPage,
              trailing: OutlinedButton.icon(
                onPressed: app.useCurrentPageAtStartup,
                icon: const Icon(Icons.push_pin_rounded, size: 16),
                label: Text(l.useCurrentPage),
              ),
            ),
          ],
        ),
        const _AppUpdateGroup(),
        _Group(
          title: l.updateNow,
          children: [
            _Row(
              title: l.autoUpdate,
              subtitle: l.descAutoUpdate,
              trailing: DropdownButton<int>(
                value: app.refreshHours,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: 0, child: Text(l.trackOff)),
                  for (final h in const [1, 3, 6, 12, 24])
                    DropdownMenuItem(value: h, child: Text(l.everyNHours(h))),
                ],
                onChanged: (v) {
                  if (v != null) app.setRefreshHours(v);
                },
              ),
            ),
            _Row(
              title: app.refreshing
                  ? l.updating
                  : (app.lastUpdated == null
                      ? l.neverUpdated
                      : l.lastUpdatedAt(
                          TimeOfDay.fromDateTime(app.lastUpdated!)
                              .format(context))),
              trailing: OutlinedButton.icon(
                onPressed: app.refreshing ? null : app.refreshContent,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(l.updateNow),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dropdown with the startup page choices (last used + fixed pages + custom).
class _StartupPicker extends StatelessWidget {
  const _StartupPicker();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;

    String labelOf(String value) {
      if (value == 'last') return l.startLast;
      final i = value.indexOf(':');
      if (i < 0) return l.startCustom;
      final sec = value.substring(0, i);
      final sel = value.substring(i + 1);
      final secName = switch (sec) {
        'movies' => l.navMovies,
        'series' => l.navSeries,
        _ => l.navLive,
      };
      final selName = switch (sel) {
        kAll => switch (sec) {
            'movies' => l.allMovies,
            'series' => l.allSeries,
            _ => l.allChannels,
          },
        kFavorites => l.favorites,
        kRecent => l.recentlyWatched,
        _ => null,
      };
      return selName == null
          ? '$secName · ${l.startCustom}'
          : '$secName · $selName';
    }

    final values = <String>[
      'last',
      for (final v in AppState.startupPresets)
        if (app.hasVod || v.startsWith('live:')) v,
    ];
    if (!values.contains(app.startupPage)) values.add(app.startupPage);

    return DropdownButton<String>(
      isExpanded: true,
      value: app.startupPage,
      items: [
        for (final v in values)
          DropdownMenuItem(value: v, child: Text(labelOf(v))),
      ],
      onChanged: (v) {
        if (v != null) app.setStartupPage(v);
      },
    );
  }
}

// --------------------------------------------------------------- Playback

class _PlaybackTab extends StatefulWidget {
  const _PlaybackTab();

  @override
  State<_PlaybackTab> createState() => _PlaybackTabState();
}

class _PlaybackTabState extends State<_PlaybackTab> {
  late final AppState _app;
  late final TextEditingController _ua;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    _ua = TextEditingController(text: _app.userAgent);
  }

  @override
  void dispose() {
    if (_ua.text.trim() != _app.userAgent) _app.setUserAgent(_ua.text.trim());
    _ua.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Group(
          title: l.skipDuration,
          children: [
            _Row(
              title: l.skipDuration,
              below: SizedBox(
                width: double.infinity,
                child: _seconds(const [5, 10, 15, 30, 60], app.skipSeconds,
                    app.setSkipSeconds),
              ),
            ),
            _Row(
              title: l.arrowSkip,
              below: SizedBox(
                width: double.infinity,
                child: _seconds(const [5, 10, 15, 30], app.arrowSeconds,
                    app.setArrowSeconds,
                    enabled: !app.arrowLinked),
              ),
            ),
            _Row(
              title: l.arrowLinked,
              trailing: _switch(app.arrowLinked, app.setArrowLinked),
            ),
          ],
        ),
        _Group(
          title: l.tabPlayback,
          children: [
            _Row(
              title: l.weakInternet,
              subtitle: l.descWeak,
              trailing: _switch(app.weakInternet, app.setWeakInternet),
            ),
            _Row(
              title: l.rememberVolume,
              trailing: _switch(app.rememberVolume, app.setRememberVolume),
            ),
            _Row(
              title: l.wheelVolume,
              trailing: _switch(app.wheelVolume, app.setWheelVolume),
            ),
          ],
        ),
        _Group(
          title: l.userAgent,
          children: [
            _Row(
              title: l.userAgent,
              subtitle: l.descUserAgent,
              below: TextField(
                controller: _ua,
                decoration: const InputDecoration(isDense: true),
                onSubmitted: (v) => app.setUserAgent(v.trim()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- Subtitles

class _SubtitlesTab extends StatelessWidget {
  const _SubtitlesTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Group(
          children: [
            _Row(
              title: l.subtitleLanguage,
              subtitle: l.descSubLang,
              trailing: DropdownButton<String>(
                value: app.subLang,
                underline: const SizedBox.shrink(),
                items: [
                  for (final c in AppState.subtitleLanguages)
                    DropdownMenuItem(value: c, child: Text(c.toUpperCase())),
                ],
                onChanged: (v) {
                  if (v != null) app.setSubLang(v);
                },
              ),
            ),
            _Row(
              title: l.subtitleColor,
              below: const Align(
                alignment: AlignmentDirectional.centerStart,
                child: SubtitleColorPicker(),
              ),
            ),
          ],
        ),
        Container(
          height: 110,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            l.subtitlePreview,
            style: TextStyle(
              color: Color(app.subColor),
              fontSize: 26,
              fontWeight: FontWeight.w600,
              backgroundColor: const Color(0x66000000),
            ),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- Accounts

class _AccountsTab extends StatelessWidget {
  const _AccountsTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Group(
          title: l.tabAccounts,
          children: [
            for (final a in app.accounts)
              InkWell(
                onTap: a.id == app.active?.id
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        app.signIn(a);
                      },
                child: _Row(
                  title: a.name,
                  subtitle: a.id == app.active?.id ? l.activeNow : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        a.id == app.active?.id
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 20,
                        color: a.id == app.active?.id ? scheme.primary : null,
                      ),
                      if (a.id != app.active?.id)
                        IconButton(
                          tooltip: l.removeAccount,
                          onPressed: () => app.removeAccount(a),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 20),
                        ),
                    ],
                  ),
                ),
              ),
            _Row(
              title: l.addSource,
              trailing: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  app.signOut();
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(l.addSource),
              ),
            ),
          ],
        ),
        _Group(
          children: [
            _Row(
              title: l.signOut,
              trailing: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                    foregroundColor: scheme.error),
                onPressed: () {
                  Navigator.of(context).pop();
                  app.signOut();
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: Text(l.signOut),
              ),
            ),
          ],
        ),
      ],
    );
  }
}


/// Version, "check for updates" and the automatic-update mode.
class _AppUpdateGroup extends StatelessWidget {
  const _AppUpdateGroup();

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UpdateService>();
    final l = context.l10n;
    final checking = up.phase == UpdatePhase.checking;
    final status = switch (up.phase) {
      UpdatePhase.checking => l.updating,
      UpdatePhase.upToDate => l.upToDate,
      UpdatePhase.error => l.updateFailed,
      UpdatePhase.available when up.release != null =>
        l.newVersion(up.release!.version),
      _ => null,
    };
    return _Group(
      title: l.updatesTitle,
      children: [
        _Row(
          title: l.versionLabel(up.current),
          subtitle: status,
          trailing: up.phase == UpdatePhase.available && up.release != null
              ? FilledButton(
                  onPressed: () => showDialog(
                      context: context, builder: (_) => const UpdateDialog()),
                  child: Text(l.installUpdate),
                )
              : OutlinedButton.icon(
                  onPressed: checking ? null : () => up.check(manual: true),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(l.checkUpdates),
                ),
        ),
        _Row(
          title: l.updatesMode,
          below: DropdownButton<UpdateMode>(
            isExpanded: true,
            value: up.mode,
            items: [
              DropdownMenuItem(
                  value: UpdateMode.auto, child: Text(l.updModeAuto)),
              DropdownMenuItem(
                  value: UpdateMode.ask, child: Text(l.updModeAsk)),
              DropdownMenuItem(
                  value: UpdateMode.off, child: Text(l.updModeOff)),
            ],
            onChanged: (v) {
              if (v != null) up.setMode(v);
            },
          ),
        ),
      ],
    );
  }
}
