import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/demo.dart';

/// A standalone entry point that draws the home screen against fixed data.
///
/// It exists so the screen can be looked at and dragged around without a
/// backend or a login. Nothing ships from here.
void main() {
  runApp(const _PreviewApp());
}

/// `?rest` draws the break between two blocks instead of one running.
final bool _resting = Uri.base.queryParameters.containsKey('rest');

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DemoApp(resting: _resting),
    );
  }
}
