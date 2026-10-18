import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/injection.dart';
import 'core/l10n/strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('vi', 'VN'),
      // Banner mất mạng xuất hiện trên mọi màn hình (CĐ 5)
      builder: (context, child) => ConnectivityBanner(child: child!),
    );
  }
}

// ── Connectivity Banner (CĐ 5) ─────────────────────────────────────────────
/// Hiện banner "Mất kết nối" ở đầu màn khi không có mạng.
class ConnectivityBanner extends StatelessWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  static bool _isOnline(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);

  Stream<bool> get _online async* {
    final c = Connectivity();
    yield _isOnline(await c.checkConnectivity());
    yield* c.onConnectivityChanged.map(_isOnline);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _online,
      initialData: true,
      builder: (context, snap) {
        final online = snap.data ?? true;
        return Column(children: [
          if (!online)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Row(children: [
                    const Icon(Icons.wifi_off, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Mất kết nối internet',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer),
                    ),
                  ]),
                ),
              ),
            ),
          Expanded(child: child),
        ]);
      },
    );
  }
}
