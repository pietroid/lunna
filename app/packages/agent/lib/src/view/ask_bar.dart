import 'dart:async';

import 'package:agent/src/models.dart';
import 'package:agent/src/view/composer.dart';
import 'package:app_ui/app_ui.dart';

/// Opens the composer, about the page it was opened on when there is one.
typedef ComposeOpener =
    Future<void> Function(BuildContext context, {AgentSubject? about});

/// {@template compose_launcher}
/// How the app opens the composer, put above every page: what the
/// composer writes goes through the app's blocs (the day, the deliveries,
/// the goals), which this package does not know.
/// {@endtemplate}
class ComposeLauncher extends InheritedWidget {
  /// {@macro compose_launcher}
  const ComposeLauncher({required this.open, required super.child, super.key});

  final ComposeOpener open;

  /// The launcher above [context], or none (the demo, the tests).
  static ComposeLauncher? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ComposeLauncher>();

  @override
  bool updateShouldNotify(ComposeLauncher oldWidget) => open != oldWidget.open;
}

/// {@template ask_dock}
/// The foot of every screen: one round button, where the + always was.
///
/// By default it is the composer's + ([ComposeButton]): whatever is typed
/// or said there is read once and comes back as one summary to confirm,
/// which replaced both the old + (a form) and the agent's bar. A screen
/// with a button of its own hands it in as [fab] (Nova rotina on Rotina,
/// a delivery on Entregas), and the notes put their dictation microphone
/// [beside] it.
///
/// **It is on every screen, in the same place.** Every tab and every page
/// floats it at [location] with [animator]: changing tabs moves nothing,
/// and a page pushed or popped slides under it while the button stays
/// still ([DockHero]). Only a sheet covers it.
/// {@endtemplate}
class AskDock extends StatelessWidget {
  /// {@macro ask_dock}
  const AskDock({
    this.fab,
    this.beside,
    this.about,
    this.hero = true,
    super.key,
  });

  /// Where every screen floats the dock: the end of the content column,
  /// over the bottom bar on the tabs and at the foot of a page elsewhere.
  static const FloatingActionButtonLocation location = AppFab.location;

  /// How a screen swaps one dock for another: in place, with no scaling out
  /// and in.
  static const FloatingActionButtonAnimator animator =
      FloatingActionButtonAnimator.noAnimation;

  /// Whether the dock is its page's [DockHero]; false when something around
  /// it already is (the notes' dock).
  final bool hero;

  /// The screen's own button; null is the composer's +.
  final Widget? fab;

  /// Drawn before the button: the notes' dictation microphone.
  final Widget? beside;

  /// The page the dock is on, which the composer is about: a task's or a
  /// delivery's.
  final AgentSubject? about;

  @override
  Widget build(BuildContext context) {
    final button =
        fab ??
        ComposeButton(
          onPressed: () {
            final launcher = ComposeLauncher.maybeOf(context);
            if (launcher != null) {
              unawaited(launcher.open(context, about: about));
            }
          },
        );
    final beside = this.beside;
    final dock = beside == null
        ? button
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [beside, const SizedBox(width: AppSpacing.s3), button],
          );
    if (!hero) return dock;

    final own = fab;
    return DockHero(
      fabIcon: own is AppFab ? own.iconData : AppIcons.plus,
      child: dock,
    );
  }
}

/// {@template dock_hero}
/// The dock, held still while a page slides in or out under it.
///
/// Every page has a dock of its own, so a push would slide one in with the
/// page and the other out with the page behind. As a hero the two are one:
/// it stays where it was (or glides the bottom bar's height, between a tab
/// and a page), drawn as a still picture of the arriving page's round
/// button ([fabIcon]), and the arriving page's dock takes over when the
/// page has landed. Sheets are not pages: they cover it.
/// {@endtemplate}
class DockHero extends StatelessWidget {
  /// {@macro dock_hero}
  const DockHero({
    required this.child,
    this.fabIcon = AppIcons.plus,
    super.key,
  });

  /// The dock itself.
  final Widget child;

  /// The glyph of the round button, for the picture drawn while the page
  /// moves.
  final AppIconData fabIcon;

  /// One dock per page, so one tag for all of them.
  static const tag = 'agent-dock';

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      // A swipe back on iOS holds it still too.
      transitionOnUserGestures: true,
      flightShuttleBuilder: (_, _, direction, from, to) {
        final arriving =
            (direction == HeroFlightDirection.push ? to : from).widget;
        final icon = arriving is DockHero ? arriving.fabIcon : fabIcon;
        // A picture, never a second live dock: nothing in it records, and
        // it reads nothing the page around it provides.
        return IgnorePointer(
          child: Align(
            alignment: Alignment.centerRight,
            child: AppFab(iconData: icon, onPressed: () {}),
          ),
        );
      },
      child: child,
    );
  }
}

/// The surface the bar and the recorder are drawn on.
class AskPill extends StatelessWidget {
  /// Creates the pill.
  const AskPill({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
  });

  /// How tall the pill is: the round button's height.
  static const height = 56.0;

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AskPill.height,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 28,
            offset: Offset(0, 8),
            spreadRadius: -10,
          ),
        ],
      ),
      child: child,
    );
  }
}
