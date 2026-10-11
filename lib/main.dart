import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'l10n/l10n.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';
import 'widgets/glass.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const IptvApp(),
    ),
  );
}

class IptvApp extends StatelessWidget {
  const IptvApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.select<AppState, Locale?>((s) => s.locale);
    return MaterialApp(
      title: 'IPTV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: locale, // null follows the system language
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final Widget body;
    if (!app.initialized) {
      body = const Center(child: CircularProgressIndicator());
    } else if (app.state == LoadState.ready) {
      body = const HomeScreen();
    } else {
      body = const LoginScreen();
    }
    return AppBackground(child: body);
  }
}
