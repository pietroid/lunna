import 'package:app_ui/app_ui.dart';
import 'package:focus/demo/demo.dart';

/// A standalone entry point that draws the home screen against fixed data.
///
/// It exists so the screen can be looked at and dragged around without a
/// backend, a Firebase project, or a login. Nothing ships from here.
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
      home: DemoApp(resting: _resting),
    );
  }
}
