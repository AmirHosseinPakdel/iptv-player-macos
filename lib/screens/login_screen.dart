import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../widgets/glass.dart';
import '../widgets/language_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  AccountKind _kind = AccountKind.xtream;

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final server = _server.text.trim();
    final host = Uri.tryParse(server.contains('://') ? server : 'http://$server')?.host;
    final name = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : ((host == null || host.isEmpty) ? server : host);
    final xtream = _kind == AccountKind.xtream;
    context.read<AppState>().signIn(Account(
          name: name,
          kind: _kind,
          server: server,
          username: xtream ? _user.text.trim() : '',
          password: xtream ? _pass.text : '',
        ));
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? context.l10n.fieldRequired : null;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final loading = app.state == LoadState.loading;
    final xtream = _kind == AccountKind.xtream;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Glass(
                  radius: 28,
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
                              ),
                            ),
                            child: const Icon(Icons.live_tv_rounded,
                                color: Colors.white, size: 32),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(l.welcomeTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(l.welcomeSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 22),
                        SegmentedButton<AccountKind>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                                value: AccountKind.xtream,
                                label: Text(l.xtreamLogin)),
                            ButtonSegment(
                                value: AccountKind.m3u,
                                label: Text(l.m3uPlaylist)),
                          ],
                          selected: {_kind},
                          onSelectionChanged: (s) =>
                              setState(() => _kind = s.first),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _name,
                          decoration: InputDecoration(hintText: l.accountName),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _server,
                          textDirection: TextDirection.ltr,
                          keyboardType: TextInputType.url,
                          validator: _required,
                          decoration: InputDecoration(
                              hintText: xtream ? l.serverUrl : l.playlistUrl),
                        ),
                        if (xtream) ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _user,
                            textDirection: TextDirection.ltr,
                            validator: _required,
                            decoration: InputDecoration(hintText: l.username),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _pass,
                            textDirection: TextDirection.ltr,
                            obscureText: true,
                            validator: _required,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(hintText: l.password),
                          ),
                        ],
                        if (app.state == LoadState.error && app.error != null) ...[
                          const SizedBox(height: 12),
                          Text(l.error(app.error!),
                              style: TextStyle(color: scheme.error)),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: loading ? null : _submit,
                          child: loading
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(l.connecting),
                                  ],
                                )
                              : Text(l.connect),
                        ),
                        if (app.accounts.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          Text(l.savedAccounts,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          for (final a in app.accounts)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.dns_rounded),
                              title: Text(a.name),
                              subtitle: Text(a.server,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: TextDirection.ltr),
                              onTap: loading ? null : () => app.connect(a),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () => app.removeAccount(a),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const PositionedDirectional(
            top: 12,
            end: 12,
            child: LanguageButton(),
          ),
        ],
      ),
    );
  }
}
