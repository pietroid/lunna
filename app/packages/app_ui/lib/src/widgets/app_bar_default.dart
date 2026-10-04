import 'package:app_ui/app_ui.dart';

/// {@template app_bar_default}
/// A default application app bar with a very light gray background
/// and a smaller title text style.
/// {@endtemplate}
class AppBarDefault extends StatelessWidget implements PreferredSizeWidget {
  /// {@macro app_bar_default}
  const AppBarDefault({
    required this.title,
    required this.onHomePressed,
    super.key,
  });

  /// The primary text displayed in the app bar.
  final String title;

  /// Called when the home button is pressed.
  final VoidCallback onHomePressed;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      leading: AppIconButton(
        iconData: AppIcons.home,
        onPressed: onHomePressed,
      ),
      title: Row(
        children: [
          Text(
            textAlign: TextAlign.start,
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
