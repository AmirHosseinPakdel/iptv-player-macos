import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import 'glass.dart';

const subtitleColors = <int>[
  0xFFFFFFFF, // white
  0xFFFFE600, // yellow
  0xFF7CFC00, // green
  0xFF00E5FF, // cyan
  0xFFFF9500, // orange
];

/// Row of color dots for the subtitle color.
class SubtitleColorPicker extends StatelessWidget {
  const SubtitleColorPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Wrap(
      spacing: 10,
      children: [
        for (final c in subtitleColors)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => app.setSubColor(c),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: app.subColor == c
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white24,
                  width: app.subColor == c ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Audio track, subtitle track, own subtitle file and subtitle color.
class TracksDialog extends StatelessWidget {
  const TracksDialog({super.key});

  String _name(BuildContext context, String id, String? title, String? lang) {
    final l = context.l10n;
    if (id == 'auto') return l.trackAuto;
    if (id == 'no') return l.trackOff;
    final parts = [if (title != null && title.isNotEmpty) title, if (lang != null && lang.isNotEmpty) lang];
    return parts.isEmpty ? '#$id' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final player = app.player;
    final l = context.l10n;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Glass(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: StreamBuilder<Tracks>(
            stream: player.stream.tracks,
            initialData: player.state.tracks,
            builder: (_, tracksSnap) => StreamBuilder<Track>(
              stream: player.stream.track,
              initialData: player.state.track,
              builder: (_, trackSnap) {
                final tracks = tracksSnap.data ?? player.state.tracks;
                final cur = trackSnap.data ?? player.state.track;
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.subtitles,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      Text(l.audioTrack,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      for (final t in tracks.audio)
                        _Option(
                          label: _name(context, t.id, t.title, t.language),
                          selected: cur.audio.id == t.id,
                          onTap: () => player.setAudioTrack(t),
                        ),
                      const SizedBox(height: 14),
                      Text(l.subtitleTrack,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      for (final t in tracks.subtitle)
                        _Option(
                          label: _name(context, t.id, t.title, t.language),
                          selected: cur.subtitle.id == t.id,
                          onTap: () => player.setSubtitleTrack(t),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.note_add_rounded, size: 18),
                        label: Text(l.addSubtitle),
                        onPressed: () async {
                          final r = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: const [
                              'srt', 'vtt', 'ass', 'ssa', 'sub'
                            ],
                          );
                          final path = r?.files.single.path;
                          if (path != null) await app.addSubtitleFile(path);
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(l.subtitleColor,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const SubtitleColorPicker(),
                      const SizedBox(height: 14),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: selected
          ? Icon(Icons.check_rounded,
              color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
