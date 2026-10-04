import 'package:app_ui/app_ui.dart';
import 'package:go_router/go_router.dart';

/// {@template menu_page}
/// Everything that is not one of the three lists: the routines, and the
/// things that have been solved.
/// {@endtemplate}
class MenuPage extends StatelessWidget {
  /// {@macro menu_page}
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s6,
              AppSpacing.s5,
              AppSpacing.s6,
              // Room under the last row so the bar never covers it.
              AppSpacing.s16 + AppSpacing.s12,
            ),
            children: [
              Text('Menu', style: AppTypography.headline),
              const SizedBox(height: AppSpacing.s5),
              AppListItem(
                title: 'Rotina',
                iconData: AppIcons.repeat,
                onTap: () => context.push<void>('/rotina'),
              ),
              AppListItem(
                title: 'Itens concluídos',
                iconData: AppIcons.check,
                onTap: () => context.push<void>('/concluidos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
