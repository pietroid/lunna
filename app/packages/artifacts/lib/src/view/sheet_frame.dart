import 'package:app_ui/app_ui.dart';

/// {@template sheet_frame}
/// The sheets of Entregas: a title, a close, and what they hold.
///
/// [tall] lets the content scroll in most of the screen, for a list like
/// the catalogue; otherwise the sheet is as tall as what it holds.
/// {@endtemplate}
class SheetFrame extends StatelessWidget {
  /// {@macro sheet_frame}
  const SheetFrame({
    required this.title,
    required this.child,
    this.tall = false,
    super.key,
  });

  /// What the sheet does.
  final String title;

  /// What it holds.
  final Widget child;

  /// Whether it takes most of the screen.
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s5,
        AppSpacing.s2,
        AppSpacing.s5,
        AppSpacing.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTypography.title)),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const AppIcon(
                  iconData: AppIcons.close,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          if (tall) Expanded(child: child) else child,
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: AppColors.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.cardRadius),
        ),
        child: SafeArea(
          top: false,
          child: tall ? SizedBox(height: height * 0.86, child: body) : body,
        ),
      ),
    );
  }
}
