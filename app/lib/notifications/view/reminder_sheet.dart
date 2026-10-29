import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:notifications/notifications.dart';

/// {@template reminder_ask}
/// What a tapped reminder asked, read again from the day when it opens: the
/// card, which of its edges, and how late that edge is now.
/// {@endtemplate}
class ReminderAsk {
  /// {@macro reminder_ask}
  const ReminderAsk({
    required this.title,
    required this.card,
    required this.edge,
    required this.hours,
    this.lateMinutes = 0,
  });

  /// The card's title, which is also the reminder's.
  final String title;

  /// A task or a fixed block, which picks the routes its answers post.
  final NotificationCard card;

  /// The edge asked about.
  final NotificationEdge edge;

  /// Its hours as the day has them now, "09:00–09:45".
  final String hours;

  /// How far past its planned end a begun block runs, on an end.
  final int lateMinutes;
}

/// {@template reminder_sheet}
/// The question a tapped reminder opens in the app.
///
/// iOS draws a notification's buttons only when it is held down, so the
/// reminder carries none: a tap opens Tempo with this sheet over it, and it
/// asks the same thing the reminder said, with the answers the card's own
/// buttons give. One accent answer (yes, it started; yes, it is over), one
/// outlined (ten minutes), and the agent, quiet, at the foot. Dismissing it
/// answers nothing.
/// {@endtemplate}
class ReminderSheet extends StatelessWidget {
  /// {@macro reminder_sheet}
  const ReminderSheet({required this.ask, super.key});

  /// What the reminder asked.
  final ReminderAsk ask;

  /// Opens the sheet over [context] and resolves to the answer chosen, or
  /// null when it was dismissed.
  static Future<NotificationAction?> show(
    BuildContext context,
    ReminderAsk ask,
  ) {
    return showModalBottomSheet<NotificationAction>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bg.withValues(alpha: 0.72),
      builder: (_) => ReminderSheet(ask: ask),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final start = ask.edge == NotificationEdge.start;
    final late = !start && ask.lateMinutes > 0;
    final task = ask.card == NotificationCard.task;

    final confirm = start
        ? (task ? l10n.controlStart : l10n.notificationActionConfirm)
        : l10n.reminderFinished;
    final later = start
        ? (task ? l10n.controlWait10 : l10n.reminderDelay10)
        : l10n.controlMore10;

    void answer(NotificationAction action) => Navigator.of(context).pop(action);

    return Material(
      color: AppColors.bg,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.cardRadius),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s6,
            AppSpacing.s5,
            AppSpacing.s6,
            AppSpacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ask.hours,
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                ask.title,
                style: AppTypography.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.s1),
              if (late)
                Text(
                  l10n.lateEnd(ask.lateMinutes),
                  style: AppTypography.bodyStrong.copyWith(
                    color: AppColors.dangerInk,
                  ),
                )
              else
                Text(
                  start ? l10n.reminderStarting : l10n.reminderEnding,
                  style: AppTypography.body.copyWith(color: AppColors.ink2),
                ),
              const SizedBox(height: AppSpacing.s5),
              AppButton.icon(
                text: confirm,
                icon: AppIcon(
                  iconData: start ? AppIcons.play : AppIcons.check,
                  size: AppSpacing.s4,
                  color: AppColors.onAccent,
                ),
                expand: true,
                onPressed: () => answer(NotificationAction.confirm),
              ),
              const SizedBox(height: AppSpacing.s2),
              AppButton(
                text: later,
                variant: AppButtonVariant.secondary,
                color: AppColors.ink,
                expand: true,
                onPressed: () => answer(NotificationAction.later),
              ),
              const SizedBox(height: AppSpacing.s2),
              AppButton.icon(
                text: l10n.notificationActionTalk(AppBrand.id),
                icon: const AppIcon(
                  iconData: AppIcons.agent,
                  size: AppSpacing.s4,
                  color: AppColors.ink2,
                ),
                variant: AppButtonVariant.tertiary,
                color: AppColors.ink2,
                expand: true,
                onPressed: () => answer(NotificationAction.talk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
