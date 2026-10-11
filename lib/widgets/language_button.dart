import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';

/// Opens a menu of all supported languages (each written in its own language).
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  static const _system = '_system';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l.language,
      icon: const Icon(Icons.language_rounded),
      onSelected: (code) => app.setLocale(code == _system ? null : Locale(code)),
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        CheckedPopupMenuItem<String>(
          value: _system,
          checked: app.locale == null,
          child: Text(l.systemDefault),
        ),
        const PopupMenuDivider(),
        for (final e in L10n.nativeNames.entries)
          CheckedPopupMenuItem<String>(
            value: e.key,
            checked: app.locale?.languageCode == e.key,
            child: Text(e.value),
          ),
      ],
    );
  }
}
