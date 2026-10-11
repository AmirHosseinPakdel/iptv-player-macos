import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/l10n/translations.dart';

void main() {
  test('every language has every English key', () {
    final english = translations['en']!.keys.toSet();
    for (final entry in translations.entries) {
      expect(entry.value.keys.toSet(), english, reason: 'language ${entry.key}');
    }
  });
}
