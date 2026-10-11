import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'epg_store.dart';
import 'l10n/l10n.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';
import 'updater.dart';
import 'widgets/update_dialog.dart';
import 'widgets/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // A silently downloaded update is installed here (restarts the app once).
  await UpdateService.applyStagedIfAny();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..init()),
        ChangeNotifierProvider(create: (_) => UpdateService()..init()),
        ChangeNotifierProxyProvider<AppState, EpgStore>(
          create: (_) => EpgStore(),
          update: (_, app, store) => store!..attach(app.xtreamService),
        ),
      ],
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
    final updates = context.watch<UpdateService>();
    // A new version was found: show the update dialog once.
    if (updates.promptPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && updates.consumePrompt()) {
          showDialog(
            context: context,
            barrierDismissible: !(updates.release?.mandatory ?? false),
            builder: (_) => const UpdateDialog(),
          );
        }
      });
    }
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
