import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import 'glass.dart';

class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;

    return Glass(
      radius: 24,
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
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
                  controls: (state) => PlayerControls(state: state),
                ),
        ),
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
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    final player = app.player;
    final channel = app.current;

    return MouseRegion(
      onHover: (_) => _poke(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _poke,
        child: Stack(
          children: [
            if (channel != null)
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
                end: 16,
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SeekButton(
                              tooltip: l.seekBack,
                              forward: false,
                              onPressed: () =>
                                  app.seekBy(const Duration(seconds: -15)),
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
                              tooltip: l.seekForward,
                              forward: true,
                              onPressed: () =>
                                  app.seekBy(const Duration(seconds: 15)),
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
                            if (channel != null)
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
    );
  }
}

/// Round "15" skip button (back or forward).
class _SeekButton extends StatelessWidget {
  const _SeekButton({
    required this.tooltip,
    required this.forward,
    required this.onPressed,
  });

  final String tooltip;
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
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Text(
              '15',
              style: TextStyle(
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
