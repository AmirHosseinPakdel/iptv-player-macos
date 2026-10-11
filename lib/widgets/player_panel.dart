import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../epg_store.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import 'glass.dart';
import 'tracks_dialog.dart';
import 'vod_panel.dart' show fmtDuration;

class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;

    return Glass(
      radius: 24,
      padding: const EdgeInsets.all(6),
      child: Stack(
        children: [
          Positioned.fill(child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(
          color: Colors.black,
          child: app.current == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_outline_rounded,
                          size: 64, color: Colors.white30),
                      const SizedBox(height: 12),
                      Text(l.selectChannel,
                          style: const TextStyle(color: Colors.white60)),
                    ],
                  ),
                )
              : Video(
                  controller: app.video,
                  subtitleViewConfiguration: SubtitleViewConfiguration(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
                    style: TextStyle(
                      color: Color(app.subColor),
                      fontSize: 34,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      backgroundColor: const Color(0x66000000),
                    ),
                  ),
                  controls: (state) => PlayerControls(state: state),
                ),
        ),
      )),
          const PositionedDirectional(
            top: 12,
            end: 12,
            child: _PanelToggles(),
          ),
        ],
      ),
    );
  }
}

/// Floating glass controls that fade out when the pointer is idle.
class PlayerControls extends StatefulWidget {
  const PlayerControls({super.key, required this.state});
  final VideoState state;

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  bool _visible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _poke();
    // Give the player the keyboard / remote focus so arrow keys work at once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().playerFocus.requestFocus();
    });
  }

  String? _toast;
  Timer? _toastTimer;

  /// Short "+5 s" / "−5 s" hint in the middle of the picture.
  void _flash(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// Keys while the video itself has focus (remote control friendly):
  /// left/right seek, OK plays/pauses, Back leaves fullscreen / the movie.
  /// Up/down move focus to the controls (or change volume when hidden).
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final app = context.read<AppState>();
    final k = e.logicalKey;
    final wasVisible = _visible;
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack) {
      if (widget.state.isFullscreen()) {
        widget.state.toggleFullscreen();
      } else if (!app.currentIsLive) {
        app.closeVod();
      } else {
        node.focusInDirection(TraversalDirection.left);
      }
      return KeyEventResult.handled;
    }
    _poke();
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    final step = app.keySeconds;
    if (k == LogicalKeyboardKey.arrowLeft) {
      app.seekBy(Duration(seconds: -step));
      _flash('−$step s');
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      app.seekBy(Duration(seconds: step));
      _flash('+$step s');
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.space) {
      app.player.playOrPause();
      return KeyEventResult.handled;
    }
    if (!wasVisible &&
        (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown)) {
      app.nudgeVolume(k == LogicalKeyboardKey.arrowUp ? 5 : -5);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _poke() {
    _hideTimer?.cancel();
    if (!_visible) setState(() => _visible = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    final player = app.player;
    final channel = app.current;

    return Focus(
      focusNode: app.playerFocus,
      onKeyEvent: _onKey,
      child: Listener(
      onPointerSignal: (event) {
        if (app.wheelVolume && event is PointerScrollEvent) {
          app.nudgeVolume(event.scrollDelta.dy < 0 ? 5 : -5);
          _poke();
        }
      },
      child: MouseRegion(
      onHover: (_) => _poke(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _poke();
          app.playerFocus.requestFocus();
        },
        onDoubleTap: () async {
          await widget.state.toggleFullscreen();
          if (mounted) _poke();
        },
        child: Stack(
          children: [
            if (channel != null && !app.currentIsLive)
              PositionedDirectional(
                top: 16,
                start: 16,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Glass(
                    radius: 14,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        color: Colors.white,
                        onPressed: app.closeVod,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 14),
                        child: Text(channel.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ),
              ),
            if (channel != null && app.currentIsLive)
              PositionedDirectional(
                top: 16,
                start: 16,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Glass(
                    radius: 14,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      channel.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            if (channel != null && app.currentIsLive)
              PositionedDirectional(
                top: 62,
                start: 16,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: _NowNext(channel: channel),
                ),
              ),
            if (_toast != null)
              Center(
                child: Glass(
                  radius: 18,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Text(_toast!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            if (app.resumePrompt != null)
              PositionedDirectional(
                top: 64,
                end: 16,
                child: _ResumePrompt(position: app.resumePrompt!),
              ),
            Center(
              child: StreamBuilder<bool>(
                stream: player.stream.buffering,
                initialData: player.state.buffering,
                builder: (_, s) => (s.data ?? false)
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const SizedBox.shrink(),
              ),
            ),
            if (app.playbackError != null)
              PositionedDirectional(
                top: 16,
                end: 100,
                child: Glass(
                  radius: 14,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(l.playbackProblem,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: IgnorePointer(
                  ignoring: !_visible,
                  child: AnimatedOpacity(
                    opacity: _visible ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Glass(
                      radius: 28,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: IconTheme(
                        data: const IconThemeData(color: Colors.white),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!app.currentIsLive) const _SeekBar(),
                            Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SeekButton(
                              tooltip: l.seekBackN(app.skipSeconds),
                              seconds: app.skipSeconds,
                              forward: false,
                              onPressed: () => app
                                  .seekBy(Duration(seconds: -app.skipSeconds)),
                            ),
                            StreamBuilder<bool>(
                              stream: player.stream.playing,
                              initialData: player.state.playing,
                              builder: (_, s) {
                                final playing = s.data ?? false;
                                return IconButton(
                                  tooltip: playing ? l.pause : l.play,
                                  iconSize: 32,
                                  onPressed: player.playOrPause,
                                  icon: Icon(playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded),
                                );
                              },
                            ),
                            _SeekButton(
                              tooltip: l.seekForwardN(app.skipSeconds),
                              seconds: app.skipSeconds,
                              forward: true,
                              onPressed: () => app
                                  .seekBy(Duration(seconds: app.skipSeconds)),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.volume_up_rounded, size: 20),
                            SizedBox(
                              width: 96,
                              height: 36,
                              child: StreamBuilder<double>(
                                stream: player.stream.volume,
                                initialData: player.state.volume,
                                builder: (_, s) => Slider(
                                  value: (s.data ?? 100).clamp(0, 100).toDouble(),
                                  min: 0,
                                  max: 100,
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.white24,
                                  onChanged: player.setVolume,
                                ),
                              ),
                            ),
                            if (channel != null && app.currentIsLive)
                              IconButton(
                                tooltip: app.isFavorite(channel)
                                    ? l.removeFavorite
                                    : l.addFavorite,
                                onPressed: () => app.toggleFavorite(channel),
                                icon: Icon(
                                  app.isFavorite(channel)
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: app.isFavorite(channel)
                                      ? const Color(0xFFFFB020)
                                      : Colors.white,
                                ),
                              ),
                            if (channel != null && app.currentIsLive)
                              IconButton(
                                tooltip: l.guide,
                                onPressed: () => _showGuide(context, channel),
                                icon: const Icon(Icons.list_alt_rounded),
                              ),
                            IconButton(
                              tooltip: l.subtitles,
                              onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => const TracksDialog()),
                              icon: const Icon(Icons.subtitles_rounded),
                            ),
                            IconButton(
                              tooltip: l.fullscreen,
                              onPressed: () async {
                                await widget.state.toggleFullscreen();
                                if (mounted) _poke();
                              },
                              icon: Icon(widget.state.isFullscreen()
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded),
                            ),
                          ],
                        ),
                          ],
                        ),
                      ),
                      ),
                    ),
                  ),
                ),
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

/// Round skip button (back or forward).
class _SeekButton extends StatelessWidget {
  const _SeekButton({
    required this.tooltip,
    required this.seconds,
    required this.forward,
    required this.onPressed,
  });

  final String tooltip;
  final int seconds;
  final bool forward;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          Icon(forward ? Icons.refresh_rounded : Icons.replay_rounded, size: 32),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              '$seconds',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Buttons to hide or show the category and channel panels.
class _PanelToggles extends StatelessWidget {
  const _PanelToggles();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    return Glass(
      radius: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l.toggleCategories,
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            color: app.showSidebar ? Colors.white : Colors.white54,
            onPressed: app.toggleSidebar,
            icon: const Icon(Icons.view_sidebar_rounded),
          ),
          IconButton(
            tooltip: l.toggleChannels,
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            color: app.showChannels ? Colors.white : Colors.white54,
            onPressed: app.toggleChannels,
            icon: const Icon(Icons.view_list_rounded),
          ),
        ],
      ),
    );
  }
}

/// Now / next programme card shown over the video.
class _NowNext extends StatefulWidget {
  const _NowNext({required this.channel});
  final Channel channel;

  @override
  State<_NowNext> createState() => _NowNextState();
}

class _NowNextState extends State<_NowNext> {
  @override
  void initState() {
    super.initState();
    context.read<EpgStore>().request(widget.channel);
  }

  @override
  void didUpdateWidget(_NowNext old) {
    super.didUpdateWidget(old);
    if (old.channel.id != widget.channel.id) {
      context.read<EpgStore>().request(widget.channel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = context.select<EpgStore, List<EpgEntry>?>(
        (s) => s.entries(widget.channel.id));
    final l = context.l10n;
    final now = DateTime.now();
    final current = nowOf(list, now);
    final next = nextOf(list, now);
    if (current == null && next == null) return const SizedBox.shrink();

    const muted = TextStyle(color: Colors.white60, fontSize: 11);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Glass(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (current != null) ...[
                Text(
                  '${l.epgNow} · ${clock(current.start)}–${clock(current.end)}',
                  style: muted,
                ),
                const SizedBox(height: 2),
                Text(
                  current.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: current.progress(now),
                    minHeight: 3,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ],
              if (next != null) ...[
                SizedBox(height: current != null ? 8 : 0),
                Text('${l.epgNext} · ${clock(next.start)}', style: muted),
                Text(
                  next.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _showGuide(BuildContext context, Channel channel) {
  context.read<EpgStore>().request(channel);
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _GuideDialog(channel: channel),
  );
}

class _GuideDialog extends StatelessWidget {
  const _GuideDialog({required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final loaded = context.select<EpgStore, List<EpgEntry>?>(
        (s) => s.entries(channel.id));
    final available = context.read<EpgStore>().available;
    final now = DateTime.now();

    final Widget body;
    if (loaded == null && available) {
      body = const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (loaded == null || loaded.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(28),
        child: Center(child: Text(l.noGuide, textAlign: TextAlign.center)),
      );
    } else {
      body = ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        children: [
          for (final e in loaded) _GuideRow(entry: e, live: e.isOn(now)),
        ],
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Glass(
          radius: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.guide,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant)),
                          Text(
                            channel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.entry, required this.live});
  final EpgEntry entry;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: live
            ? scheme.primary.withValues(alpha: 0.18)
            : scheme.onSurface.withValues(alpha: 0.05),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '${clock(entry.start)}–${clock(entry.end)}',
              textDirection: TextDirection.ltr,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (entry.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entry.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Position slider with elapsed / total time, for movies and episodes.
class _SeekBar extends StatefulWidget {
  const _SeekBar();

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final player = context.read<AppState>().player;
    return SizedBox(
      width: 520,
      height: 34,
      child: StreamBuilder<Duration>(
        stream: player.stream.position,
        initialData: player.state.position,
        builder: (_, pos) => StreamBuilder<Duration>(
          stream: player.stream.duration,
          initialData: player.state.duration,
          builder: (_, dur) {
            final total = (dur.data ?? Duration.zero).inMilliseconds.toDouble();
            final now = (pos.data ?? Duration.zero).inMilliseconds.toDouble();
            final value = (_drag ?? now).clamp(0, total > 0 ? total : 1).toDouble();
            return Row(
              children: [
                Text(fmtDuration(Duration(milliseconds: value.toInt())),
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: value,
                    min: 0,
                    max: total > 0 ? total : 1,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChanged: total > 0 ? (v) => setState(() => _drag = v) : null,
                    onChangeEnd: (v) {
                      player.seek(Duration(milliseconds: v.toInt()));
                      setState(() => _drag = null);
                    },
                  ),
                ),
                Text(fmtDuration(Duration(milliseconds: total.toInt())),
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ],
            );
          },
        ),
      ),
    );
  }
}


/// "Resuming from 12:30 in 7 s" with Resume now / Start over.
class _ResumePrompt extends StatefulWidget {
  const _ResumePrompt({required this.position});
  final Duration position;

  @override
  State<_ResumePrompt> createState() => _ResumePromptState();
}

class _ResumePromptState extends State<_ResumePrompt> {
  int _left = 7;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) {
        t.cancel();
        context.read<AppState>().resumeNow();
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final l = context.l10n;
    return Glass(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.resumeIn(fmtDuration(widget.position), _left),
              style: const TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(onPressed: app.resumeNow, child: Text(l.resumeNow)),
              const SizedBox(width: 10),
              OutlinedButton(
                  onPressed: app.startOverNow, child: Text(l.startOver)),
            ],
          ),
        ],
      ),
    );
  }
}
