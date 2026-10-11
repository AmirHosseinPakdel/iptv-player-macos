import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import 'glass.dart';

String fmtDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Poster grid for the movies and series sections.
class VodGrid extends StatelessWidget {
  const VodGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    final movies = app.section == Section.movies;
    final state = movies ? app.moviesState : app.seriesState;

    if (state == LoadState.loading || state == LoadState.idle) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state == LoadState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.errGeneric),
            const SizedBox(height: 8),
            TextButton(onPressed: app.reloadSection, child: Text(l.connect)),
          ],
        ),
      );
    }

    final items = movies
        ? [
            for (final m in app.visibleMovies)
              _Card(
                title: m.name,
                image: m.poster,
                rating: m.rating,
                fav: app.favMovies.contains(m.id),
                onFav: () => app.toggleFavMovie(m.id),
                onTap: () => showDialog(
                    context: context, builder: (_) => MovieDialog(movie: m)),
              )
          ]
        : [
            for (final s in app.visibleSeries)
              _Card(
                title: s.name,
                image: s.cover,
                rating: s.rating,
                fav: app.favSeries.contains(s.id),
                onFav: () => app.toggleFavSeries(s.id),
                onTap: () => showDialog(
                    context: context, builder: (_) => SeriesDialog(series: s)),
              )
          ];
    if (items.isEmpty) return Center(child: Text(l.noChannels));

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        childAspectRatio: 0.58,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    this.image,
    this.rating,
    required this.onTap,
    this.fav = false,
    this.onFav,
  });
  final bool fav;
  final VoidCallback? onFav;
  final String title;
  final String? image;
  final double? rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FocusRing(
      child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Poster(url: image, radius: 12),
                PositionedDirectional(
                  top: 4,
                  start: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onFav,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.black45, shape: BoxShape.circle),
                      child: Icon(
                        fav ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 18,
                        color: fav ? const Color(0xFFFFB020) : Colors.white,
                      ),
                    ),
                  ),
                ),
                if (rating != null && rating! > 0)
                  PositionedDirectional(
                    top: 6,
                    end: 6,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 12, color: Color(0xFFFFB020)),
                          const SizedBox(width: 2),
                          Text(rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.onSurface)),
        ],
      ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({this.url, this.radius = 12});
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      color: scheme.onSurface.withValues(alpha: 0.08),
      child: Icon(Icons.movie_rounded, color: scheme.onSurfaceVariant),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null || url!.isEmpty
          ? fallback
          : Image.network(url!,
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, __, ___) => fallback),
    );
  }
}

class MovieDialog extends StatefulWidget {
  const MovieDialog({super.key, required this.movie});
  final VodItem movie;

  @override
  State<MovieDialog> createState() => _MovieDialogState();
}

class _MovieDialogState extends State<MovieDialog> {
  VodDetail? _detail;

  @override
  void initState() {
    super.initState();
    final svc = context.read<AppState>().xtreamService;
    svc?.vodInfo(widget.movie.id).then((d) {
      if (mounted) setState(() => _detail = d);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final l = context.l10n;
    final m = widget.movie;
    final key = 'm:${m.id}';
    final resume = app.resumePosition(key);
    final d = _detail;

    void play({bool fromStart = false}) {
      final svc = app.xtreamService;
      if (svc == null) return;
      Navigator.of(context).pop();
      app.playVod(key, m.name, svc.movieUrl(m), fromStart: fromStart);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Glass(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 170,
                  height: 255,
                  child: _Poster(url: m.poster, radius: 14)),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(m.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                      ),
                      Builder(builder: (c) {
                        final fav = c.select<AppState, bool>(
                            (s) => s.favMovies.contains(m.id));
                        return IconButton(
                          onPressed: () => app.toggleFavMovie(m.id),
                          icon: Icon(
                              fav ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: fav ? const Color(0xFFFFB020) : null),
                        );
                      }),
                    ]),
                    if (app.isWatched(key))
                      Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 16, color: Color(0xFF30D158)),
                        const SizedBox(width: 4),
                        Text(l.watched,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF30D158))),
                      ]),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (d != null && d.year.isNotEmpty) d.year,
                        if (d != null && d.duration.isNotEmpty) d.duration,
                        if (d != null && d.genre.isNotEmpty) d.genre,
                      ].join('  ·  '),
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 130),
                      child: SingleChildScrollView(
                        child: Text(
                          d == null || d.plot.isEmpty ? l.noPlot : d.plot,
                          style: const TextStyle(fontSize: 13.5, height: 1.4),
                        ),
                      ),
                    ),
                    if (d != null && d.cast.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(d.cast,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => play(),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(resume == null
                              ? l.play
                              : l.resumeFrom(fmtDuration(resume))),
                        ),
                        if (resume != null)
                          OutlinedButton(
                              onPressed: () => play(fromStart: true),
                              child: Text(l.startOver)),
                      ],
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

class SeriesDialog extends StatefulWidget {
  const SeriesDialog({super.key, required this.series});
  final SeriesItem series;

  @override
  State<SeriesDialog> createState() => _SeriesDialogState();
}

class _SeriesDialogState extends State<SeriesDialog> {
  SeriesDetail? _detail;
  bool _failed = false;
  int? _season;

  @override
  void initState() {
    super.initState();
    final svc = context.read<AppState>().xtreamService;
    svc?.seriesInfo(widget.series.id).then((d) {
      if (!mounted) return;
      setState(() {
        _detail = d;
        final t = _target(context.read<AppState>(), d);
        _season = t?.season ??
            (d.seasons.keys.isEmpty ? null : d.seasons.keys.first);
      });
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  /// The episode to continue with: the one in progress, else the next one.
  Episode? _target(AppState app, SeriesDetail d) {
    final all = [for (final n in d.seasons.keys) ...d.seasons[n]!];
    if (all.isEmpty) return null;
    final lastKey = app.lastEpisodeKey(widget.series.id);
    if (lastKey == null) return all.first;
    final i = all.indexWhere((e) => 'e:${e.id}' == lastKey);
    if (i < 0) return all.first;
    if (app.resumePosition(lastKey) != null) return all[i];
    if (app.isWatched(lastKey)) return i + 1 < all.length ? all[i + 1] : all[i];
    return all[i];
  }

  void _playEpisode(AppState app, Episode e) {
    final svc = app.xtreamService;
    if (svc == null) return;
    Navigator.of(context).pop();
    app.playVod('e:${e.id}', '${widget.series.name} · ${e.title}',
        svc.episodeUrl(e),
        seriesId: widget.series.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final l = context.l10n;
    final s = widget.series;
    final target = _detail == null ? null : _target(app, _detail!);
    final d = _detail;
    final scheme = Theme.of(context).colorScheme;
    final episodes = d == null || _season == null
        ? <Episode>[]
        : (d.seasons[_season] ?? <Episode>[]);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Glass(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: 100,
                      height: 150,
                      child: _Poster(url: s.cover, radius: 12)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(s.name,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w700)),
                          ),
                          Builder(builder: (c) {
                            final fav = c.select<AppState, bool>(
                                (x) => x.favSeries.contains(s.id));
                            return IconButton(
                              onPressed: () => app.toggleFavSeries(s.id),
                              icon: Icon(
                                  fav
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: fav ? const Color(0xFFFFB020) : null),
                            );
                          }),
                        ]),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 70),
                          child: SingleChildScrollView(
                            child: Text(
                              (d?.plot.isNotEmpty ?? false)
                                  ? d!.plot
                                  : (s.plot.isNotEmpty ? s.plot : l.noPlot),
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ),
                        if (target != null) ...[
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: () => _playEpisode(app, target),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(() {
                              final pos = app.resumePosition('e:${target.id}');
                              final base =
                                  '${l.continueEpisode} S${target.season}E${target.number}';
                              return pos == null
                                  ? base
                                  : '$base · ${fmtDuration(pos)}';
                            }()),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (d != null && d.seasons.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final n in d.seasons.keys)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Text(l.seasonN(n)),
                            selected: _season == n,
                            onSelected: (_) => setState(() => _season = n),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: d == null
                    ? Center(
                        child: _failed
                            ? Text(l.errGeneric)
                            : const CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: episodes.length,
                        itemBuilder: (_, i) {
                          final e = episodes[i];
                          final key = 'e:${e.id}';
                          final resume = app.resumePosition(key);
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: app.isWatched(key)
                                  ? const Color(0xFF30D158)
                                  : scheme.primary.withValues(alpha: 0.2),
                              child: app.isWatched(key)
                                  ? const Icon(Icons.check_rounded,
                                      size: 16, color: Colors.white)
                                  : Text('${e.number}',
                                      style: const TextStyle(fontSize: 12)),
                            ),
                            title: Text(e.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: resume != null
                                ? Text(l.resumeFrom(fmtDuration(resume)))
                                : (e.duration.isNotEmpty
                                    ? Text(e.duration)
                                    : null),
                            trailing: const Icon(Icons.play_arrow_rounded),
                            onTap: () => _playEpisode(app, e),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
