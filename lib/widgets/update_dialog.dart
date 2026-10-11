import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../updater.dart';
import 'glass.dart';

/// "A new version is available" with release notes and a one-click update.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UpdateService>();
    final l = context.l10n;
    final r = up.release;
    final scheme = Theme.of(context).colorScheme;
    final busy = up.phase == UpdatePhase.downloading;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
        child: Glass(
          radius: 24,
          padding: const EdgeInsets.all(22),
          child: r == null
              ? const SizedBox.shrink()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.system_update_alt_rounded,
                          color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l.newVersion(r.version),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(l.versionLabel(up.current),
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                    if (r.notes.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(l.releaseNotes,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(r.notes,
                              style: const TextStyle(fontSize: 13, height: 1.4)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (busy) ...[
                      LinearProgressIndicator(
                          value: up.progress > 0 ? up.progress : null),
                      const SizedBox(height: 6),
                      Text(l.downloading,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ] else if (up.phase == UpdatePhase.error)
                      Text(l.updateFailed, style: TextStyle(color: scheme.error))
                    else if (up.revealFallback)
                      Text(l.revealUpdate),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        if (!r.mandatory) ...[
                          TextButton(
                            onPressed: busy
                                ? null
                                : () {
                                    up.skipThisVersion();
                                    Navigator.of(context).pop();
                                  },
                            child: Text(l.skipVersion),
                          ),
                          TextButton(
                            onPressed:
                                busy ? null : () => Navigator.of(context).pop(),
                            child: Text(l.later),
                          ),
                        ],
                        FilledButton(
                          onPressed: busy ? null : up.installNow,
                          child: Text(l.installUpdate),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
