import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models.dart';
import 'translations.dart';

/// Lightweight localization: a key lookup with English fallback.
class L10n {
  const L10n(this.locale);
  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
    Locale('de'),
    Locale('zh'),
    Locale('es'),
    Locale('fr'),
    Locale('ar'),
    Locale('tr'),
    Locale('ru'),
    Locale('pt'),
    Locale('it'),
    Locale('hi'),
  ];

  /// Each language written in itself, for the language picker.
  static const nativeNames = <String, String>{
    'en': 'English',
    'fa': 'فارسی',
    'de': 'Deutsch',
    'zh': '中文',
    'es': 'Español',
    'fr': 'Français',
    'ar': 'العربية',
    'tr': 'Türkçe',
    'ru': 'Русский',
    'pt': 'Português',
    'it': 'Italiano',
    'hi': 'हिन्दी',
  };

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  static L10n of(BuildContext context) =>
      Localizations.of<L10n>(context, L10n) ?? const L10n(Locale('en'));

  String _t(String key, [Map<String, String> args = const {}]) {
    var s = translations[locale.languageCode]?[key] ??
        translations['en']![key] ??
        key;
    args.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  String error(IptvException e) => e.key == 'errHttp'
      ? _t('errHttp', {'code': '${e.code}'})
      : _t(e.key);

  String get signIn => _t('signIn');
  String get accountName => _t('accountName');
  String get xtreamLogin => _t('xtreamLogin');
  String get m3uPlaylist => _t('m3uPlaylist');
  String get serverUrl => _t('serverUrl');
  String get playlistUrl => _t('playlistUrl');
  String get username => _t('username');
  String get password => _t('password');
  String get connect => _t('connect');
  String get connecting => _t('connecting');
  String get savedAccounts => _t('savedAccounts');
  String get allChannels => _t('allChannels');
  String get favorites => _t('favorites');
  String get recentlyWatched => _t('recentlyWatched');
  String get categories => _t('categories');
  String get searchChannels => _t('searchChannels');
  String get noChannels => _t('noChannels');
  String get selectChannel => _t('selectChannel');
  String get signOut => _t('signOut');
  String get language => _t('language');
  String get systemDefault => _t('systemDefault');
  String get playbackProblem => _t('playbackProblem');
  String get play => _t('play');
  String get pause => _t('pause');
  String get addFavorite => _t('addFavorite');
  String get removeFavorite => _t('removeFavorite');
  String get fullscreen => _t('fullscreen');
  String get previousChannel => _t('previousChannel');
  String get nextChannel => _t('nextChannel');
  String get seekBack => _t('seekBack');
  String get seekForward => _t('seekForward');
  String get weakInternet => _t('weakInternet');
  String get errUnreachable => _t('errUnreachable');
  String get errUnexpected => _t('errUnexpected');
  String get errLogin => _t('errLogin');
  String get errGeneric => _t('errGeneric');
  String get fieldRequired => _t('fieldRequired');
  String get welcomeTitle => _t('welcomeTitle');
  String get welcomeSubtitle => _t('welcomeSubtitle');
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      translations.containsKey(locale.languageCode);

  @override
  Future<L10n> load(Locale locale) => SynchronousFuture<L10n>(L10n(locale));

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

extension L10nContext on BuildContext {
  L10n get l10n => L10n.of(this);
}
