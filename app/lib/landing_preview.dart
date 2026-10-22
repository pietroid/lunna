import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth/auth.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/demo.dart';
import 'package:lunna/landing/landing.dart';

/// The landing page, signed out, for prints. Nothing ships from here.
///
/// `?s=<n>`: 1 the wide page on Peça, 2 on Entregas, 3 scrolled to what
/// is under the hero; 4 the narrow page at its top, 5 at Peça's plan, 6 at
/// Entregas.
void main() {
  runApp(const _PreviewApp());
}

final int _scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

/// Where each scene's page starts, in logical pixels.
const _scroll = {3: 860.0, 5: 520.0, 6: 1090.0};

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AuthScreen(
          authRepository: const _SignedOut(),
          child: LandingPage(
            chapter: _scene == 2 ? DemoChapter.deliveries : DemoChapter.ask,
            scrollController: ScrollController(
              initialScrollOffset: _scroll[_scene] ?? 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nobody signed in, and nobody signs in.
class _SignedOut extends AuthRepository {
  const _SignedOut();

  @override
  Stream<AppUser?> get user => const Stream.empty();

  @override
  AppUser? get currentUser => null;

  @override
  Future<String?> token() async => null;

  @override
  Future<AppUser?> restore() async => null;

  @override
  Future<void> signInWithGoogle() => Completer<void>().future;

  @override
  Future<void> signOut() async {}
}
