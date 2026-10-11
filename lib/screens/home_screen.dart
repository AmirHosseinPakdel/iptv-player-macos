import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../epg_store.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../widgets/glass.dart';
import '../widgets/player_panel.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/vod_panel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final showSidebar = context.select<AppState, bool>((s) => s.showSidebar);
    final showChannels = context.select<AppState, bool>((s) => s.showChannels);
    final app = context.read<AppState>();
    final live = context.select<AppState, bool>((s) => s.section == Section.live);
    final browsing = context.select<AppState, bool>((s) => s.vodBrowse);

    return CallbackShortcuts(
      bindings: {
        // Cmd+1 / Cmd+2 hide or show the two side panels.
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
            app.toggleSidebar,
        const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
            app.toggleChannels,
        // Remote-control / media keys (Android TV, keyboards with media keys).
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
            app.player.playOrPause(),
        const SingleActivator(LogicalKeyboardKey.mediaPlay): () =>
            app.player.play(),
        const SingleActivator(LogicalKeyboardKey.mediaPause): () =>
            app.player.pause(),
        const SingleActivator(LogicalKeyboardKey.mediaFastForward): () =>
            app.seekBy(Duration(seconds: app.skipSeconds)),
        const SingleActivator(LogicalKeyboardKey.mediaRewind): () =>
            app.seekBy(Duration(seconds: -app.skipSeconds)),
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () =>
            app.step(1),
        const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): () =>
            app.step(-1),
        const SingleActivator(LogicalKeyboardKey.channelUp): () => app.step(1),
        const SingleActivator(LogicalKeyboardKey.channelDown): () =>
            app.step(-1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Collapsible(
                    visible: showSidebar, width: 232, child: const _Sidebar()),
                if (live) ...[
                  _Collapsible(
                      visible: showChannels,
                      width: 340,
                      child: const _ChannelPanel()),
                  const Expanded(child: PlayerPanel()),
                ] else
                  Expanded(
                    child: browsing
                        ? const _ChannelPanel()
                        : const PlayerPanel(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Slides a panel (and the gap after it) in and out of the layout.
class _Collapsible extends StatelessWidget {
  const _Collapsible({
    required this.visible,
    required this.width,
    required this.child,
  });

  final bool visible;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: visible ? width + 12 : 0,
      child: ClipRect(
        child: OverflowBox(
          alignment: AlignmentDirectional.centerStart,
          minWidth: 0,
          maxWidth: width + 12,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Glass(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
                    ),
                  ),
                  child: const Icon(Icons.live_tv_rounded,
                      color: Colors.white, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('IPTV',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(
                        app.active?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (app.hasVod) const _SectionTabs(),
          if (app.hasVod) const SizedBox(height: 10),
          ..._navFor(context, app),
          Row(
            children: [
              IconButton(
                tooltip: app.refreshing ? l.updating : l.updateNow,
                onPressed: app.refreshing ? null : app.refreshContent,
                icon: app.refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: l.settings,
                onPressed: () => showDialog(
                    context: context, builder: (_) => const SettingsDialog()),
                icon: const Icon(Icons.settings_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.onContext,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final void Function(Offset)? onContext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    final muted = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    return GestureDetector(
      onSecondaryTapDown:
          onContext == null ? null : (d) => onContext!(d.globalPosition),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          onLongPress: onContext == null
              ? null
              : () {
                  final box = context.findRenderObject() as RenderBox;
                  onContext!(box.localToGlobal(box.size.center(Offset.zero)));
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontSize: 13.5),
                  ),
                ),
                Text('$count', style: TextStyle(color: muted, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _ChannelPanel extends StatelessWidget {
  const _ChannelPanel();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    final live = app.section == Section.live;
    final list = live ? app.visibleChannels : const <Channel>[];

    return Glass(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey(app.section),
                    onChanged: app.setQuery,
                    decoration: InputDecoration(
                      hintText: switch (app.section) {
                        Section.live => l.searchChannels,
                        Section.movies => l.searchMovies,
                        Section.series => l.searchSeries,
                      },
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.sortAz,
                  onPressed: app.toggleSort,
                  icon: Icon(Icons.sort_by_alpha_rounded,
                      color: app.sortAz
                          ? Theme.of(context).colorScheme.primary
                          : null),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (v) {
                    if (v == 'hidden') app.showAllHidden();
                    if (v == 'reload') app.reloadSection();
                  },
                  itemBuilder: (_) => [
                    if (app.hiddenCount > 0)
                      PopupMenuItem(
                          value: 'hidden',
                          child: Text('${l.showHidden} (${app.hiddenCount})')),
                    if (!live)
                      const PopupMenuItem(
                          value: 'reload', child: Text('Reload')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: !live
                ? const VodGrid()
                : list.isEmpty
                    ? Center(child: Text(l.noChannels))
                    : ListView.builder(
                        itemCount: list.length,
                        itemExtent: 64,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        itemBuilder: (_, i) => _ChannelTile(channel: list[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

Future<void> _contextMenu(
    BuildContext context, Offset pos, String label, VoidCallback action) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final v = await showMenu<bool>(
    context: context,
    position: RelativeRect.fromRect(
        pos & const Size(1, 1), Offset.zero & overlay.size),
    items: [PopupMenuItem(value: true, child: Text(label))],
  );
  if (v == true) action();
}

/// Live / Movies / Series switcher (only for Xtream accounts).
class _SectionTabs extends StatelessWidget {
  const _SectionTabs();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    return SegmentedButton<Section>(
      showSelectedIcon: false,
      style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4))),
      segments: [
        ButtonSegment(
            value: Section.live,
            tooltip: l.navLive,
            icon: const Icon(Icons.live_tv_rounded, size: 18)),
        ButtonSegment(
            value: Section.movies,
            tooltip: l.navMovies,
            icon: const Icon(Icons.movie_rounded, size: 18)),
        ButtonSegment(
            value: Section.series,
            tooltip: l.navSeries,
            icon: const Icon(Icons.video_library_rounded, size: 18)),
      ],
      selected: {app.section},
      onSelectionChanged: (v) => app.setSection(v.first),
    );
  }
}

List<Widget> _navFor(BuildContext context, AppState app) {
  final l = context.l10n;
  final section = app.section;
  final cats = switch (section) {
    Section.live => app.categories,
    Section.movies => app.movieCategories,
    Section.series => app.seriesCategories,
  };
  final counts = switch (section) {
    Section.live => app.categoryCounts,
    Section.movies => app.movieCounts,
    Section.series => app.seriesCounts,
  };
  final total = switch (section) {
    Section.live => app.channels.length,
    Section.movies => app.movies.length,
    Section.series => app.seriesItems.length,
  };
  final current = app.currentSelection;
  final sectionName = switch (section) {
    Section.live => l.navLive,
    Section.movies => l.navMovies,
    Section.series => l.navSeries,
  };
  return [
    _GroupHeader(
      label: sectionName,
      collapsed: app.collapseQuick,
      onTap: app.toggleQuick,
    ),
    if (!app.collapseQuick) ...[
    _NavItem(
      icon: Icons.apps_rounded,
      label: switch (section) {
        Section.live => l.allChannels,
        Section.movies => l.allMovies,
        Section.series => l.allSeries,
      },
      count: total,
      selected: current == kAll,
      onTap: () => app.select(kAll),
    ),
    _NavItem(
      icon: Icons.star_rounded,
      label: l.favorites,
      count: switch (section) {
        Section.live => app.favorites.length,
        Section.movies => app.favMovies.length,
        Section.series => app.favSeries.length,
      },
      selected: current == kFavorites,
      onTap: () => app.select(kFavorites),
    ),
    if (section == Section.live) ...[
      _NavItem(
        icon: Icons.history_rounded,
        label: l.recentlyWatched,
        count: app.recent.length,
        selected: current == kRecent,
        onTap: () => app.select(kRecent),
      ),
    ],
    ],
    _GroupHeader(
      label: l.categories,
      collapsed: app.collapseCats,
      onTap: app.toggleCats,
    ),
    if (app.collapseCats)
      const Spacer()
    else
    Expanded(
      child: ListView(
        children: [
          for (final Category c in cats)
            if ((counts[c.id] ?? 0) > 0 && !app.isCategoryHidden(section, c.id))
              _NavItem(
                icon: Icons.folder_rounded,
                label: c.name,
                count: counts[c.id] ?? 0,
                selected: current == c.id,
                onTap: () => app.select(c.id),
                onContext: (pos) => _contextMenu(context, pos, l.hideCategory,
                    () => app.hideCategory(section, c.id)),
              ),
        ],
      ),
    ),
  ];
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final selected =
        context.select<AppState, bool>((s) => s.current?.id == channel.id);
    final fav =
        context.select<AppState, bool>((s) => s.favorites.contains(channel.id));
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => app.play(channel),
          onLongPress: () {
            final box = context.findRenderObject() as RenderBox;
            _contextMenu(context, box.localToGlobal(box.size.center(Offset.zero)),
                context.l10n.hideChannel, () => app.hideChannel(channel));
          },
          onSecondaryTapDown: (d) => _contextMenu(context, d.globalPosition,
              context.l10n.hideChannel, () => app.hideChannel(channel)),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 2),
            child: Row(
              children: [
                _Logo(url: channel.logo),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      _NowLine(channel: channel),
                    ],
                  ),
                ),
                IconButton(
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  tooltip: fav ? context.l10n.removeFavorite : context.l10n.addFavorite,
                  onPressed: () => app.toggleFavorite(channel),
                  icon: Icon(
                    fav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: fav ? const Color(0xFFFFB020) : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Icon(Icons.tv_rounded, size: 18, color: scheme.onSurfaceVariant);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: scheme.onSurface.withValues(alpha: 0.07),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? placeholder
          : Padding(
              padding: const EdgeInsets.all(3),
              child: Image.network(
                url!,
                fit: BoxFit.contain,
                cacheWidth: 76,
                errorBuilder: (_, __, ___) => placeholder,
              ),
            ),
    );
  }
}

/// "What's on now" under a channel name, with a thin progress bar.
class _NowLine extends StatefulWidget {
  const _NowLine({required this.channel});
  final Channel channel;

  @override
  State<_NowLine> createState() => _NowLineState();
}

class _NowLineState extends State<_NowLine> {
  @override
  void initState() {
    super.initState();
    context.read<EpgStore>().request(widget.channel);
  }

  @override
  void didUpdateWidget(_NowLine old) {
    super.didUpdateWidget(old);
    if (old.channel.id != widget.channel.id) {
      context.read<EpgStore>().request(widget.channel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = context.select<EpgStore, List<EpgEntry>?>(
        (s) => s.entries(widget.channel.id));
    final now = DateTime.now();
    final entry = nowOf(list, now);
    if (entry == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: entry.progress(now),
            minHeight: 2.5,
            backgroundColor: scheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }
}


/// Small clickable heading that folds / unfolds the group below it.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.collapsed,
    required this.onTap,
  });
  final String label;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              AnimatedRotation(
                turns: collapsed ? -0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.expand_more_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
