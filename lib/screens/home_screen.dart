import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../widgets/glass.dart';
import '../widgets/language_button.dart';
import '../widgets/player_panel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(width: 232, child: _Sidebar()),
            SizedBox(width: 12),
            SizedBox(width: 340, child: _ChannelPanel()),
            SizedBox(width: 12),
            Expanded(child: PlayerPanel()),
          ],
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
          _NavItem(
            icon: Icons.apps_rounded,
            label: l.allChannels,
            count: app.channels.length,
            selected: app.selection == kAll,
            onTap: () => app.select(kAll),
          ),
          _NavItem(
            icon: Icons.star_rounded,
            label: l.favorites,
            count: app.favorites.length,
            selected: app.selection == kFavorites,
            onTap: () => app.select(kFavorites),
          ),
          _NavItem(
            icon: Icons.history_rounded,
            label: l.recentlyWatched,
            count: app.recent.length,
            selected: app.selection == kRecent,
            onTap: () => app.select(kRecent),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
            child: Text(
              l.categories,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final Category c in app.categories)
                  if ((app.categoryCounts[c.id] ?? 0) > 0)
                    _NavItem(
                      icon: Icons.folder_rounded,
                      label: c.name,
                      count: app.categoryCounts[c.id] ?? 0,
                      selected: app.selection == c.id,
                      onTap: () => app.select(c.id),
                    ),
              ],
            ),
          ),
          Row(
            children: [
              const LanguageButton(),
              IconButton(
                tooltip: l.weakInternet,
                onPressed: () => app.setWeakInternet(!app.weakInternet),
                icon: Icon(
                  Icons.network_check_rounded,
                  color: app.weakInternet ? scheme.primary : null,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TextButton.icon(
                      onPressed: app.signOut,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(l.signOut),
                    ),
                  ),
                ),
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
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    final muted = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
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
    );
  }
}

class _ChannelPanel extends StatelessWidget {
  const _ChannelPanel();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    final list = app.visibleChannels;

    return Glass(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: app.setQuery,
              decoration: InputDecoration(
                hintText: l.searchChannels,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text(l.noChannels))
                : ListView.builder(
                    itemCount: list.length,
                    itemExtent: 58,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    itemBuilder: (_, i) => _ChannelTile(channel: list[i]),
                  ),
          ),
        ],
      ),
    );
  }
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
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 2),
            child: Row(
              children: [
                _Logo(url: channel.logo),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
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
