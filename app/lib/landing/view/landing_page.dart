import 'dart:ui';

import 'package:app_ui/app_ui.dart';
import 'package:auth/auth.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/demo.dart';
import 'package:lunna/landing/widgets/chapters.dart';
import 'package:lunna/landing/widgets/phone_frame.dart';

/// {@template landing_page}
/// What someone who is not signed in sees: what Lunna is, with the app itself
/// running in a phone beside it.
///
/// The page is about three things, the tabs of the app said in words: Peça
/// (the agent), Tempo and Entregas. On a wide screen they are listed beside
/// the phone, and the one chosen is what the phone shows; it opens on Peça,
/// with the agent answering the first example ask.
///
/// It is drawn inside an [AuthScreen], and signing in is one quiet word in
/// the corner. The page is there to be read, and the person it lets in
/// already knows where to tap.
///
/// While it is up, the app's clock reads ten in the morning ([DemoClock]).
///
/// On a narrow screen there is no phone. The screen already is one, and a
/// phone drawn inside it would be a thumbnail: each chapter shows its piece
/// of the app instead, drawn by the app's own widgets.
/// {@endtemplate}
class LandingPage extends StatefulWidget {
  /// {@macro landing_page}
  const LandingPage({
    this.chapter = DemoChapter.ask,
    this.scrollController,
    super.key,
  });

  /// The chapter the phone opens on.
  final DemoChapter chapter;

  /// The page's scroll, for whoever needs to start it lower.
  final ScrollController? scrollController;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  /// Below this width the page is one column and the phone is left out.
  static const _wide = 960.0;

  static const _maxWidth = 1160.0;

  late final _demo = DemoController(chapter: widget.chapter);

  @override
  void initState() {
    super.initState();
    // The demo is a working day, whatever the hour of the visit.
    DemoClock.pin();
  }

  @override
  void dispose() {
    DemoClock.unpin();
    _demo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wide;
        final gutter = wide ? AppSpacing.s12 : AppSpacing.s6;

        return SingleChildScrollView(
          controller: widget.scrollController,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _TopBar(),
                      if (wide)
                        _WideHero(height: constraints.maxHeight, demo: _demo)
                      else ...[
                        const Padding(
                          padding: EdgeInsets.only(
                            top: AppSpacing.s12,
                            bottom: AppSpacing.s16,
                          ),
                          child: _Pitch(wide: false),
                        ),
                        const ChapterPieces(),
                      ],
                      _Section(
                        title: l10n.landingMoreTitle,
                        child: _Columns(
                          wide: wide,
                          children: [
                            _Part(
                              icon: AppIcons.repeat,
                              title: l10n.landingPartRoutinesTitle,
                              text: l10n.landingPartRoutinesText,
                            ),
                            _Part(
                              icon: AppIcons.timer,
                              title: l10n.landingPartRemindersTitle,
                              text: l10n.landingPartRemindersText,
                            ),
                            _Part(
                              icon: AppIcons.microphone,
                              title: l10n.landingPartVoiceTitle,
                              text: l10n.landingPartVoiceText,
                            ),
                          ],
                        ),
                      ),
                      _Section(
                        title: l10n.landingDayTitle,
                        child: _Columns(
                          wide: wide,
                          children: [
                            _Use(l10n.landingUseAsk),
                            _Use(l10n.landingUseHour),
                            _Use(l10n.landingUsePause),
                            _Use(l10n.landingUseDeliver),
                          ],
                        ),
                      ),
                      const _Footer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s5),
      child: Row(
        children: [
          Image.asset(AppBrand.markAsset, package: 'app_ui', height: 38),
          const SizedBox(width: AppSpacing.s3),
          Text(
            context.l10n.appName(AppBrand.id),
            style: AppTypography.onest(
              size: 32,
              weight: FontWeight.w500,
              tracking: -0.02,
            ),
          ),
          const Spacer(),
          AuthSignInButton(compact: true, label: context.l10n.authSignIn),
        ],
      ),
    );
  }
}

/// The pitch and the chapters on the left, the phone on the right, filling
/// the first screen.
class _WideHero extends StatelessWidget {
  const _WideHero({required this.height, required this.demo});

  /// The height of the window, which the phone is sized against.
  final double height;

  /// Which chapter the phone shows, shared with the list beside it.
  final DemoController demo;

  @override
  Widget build(BuildContext context) {
    // The phone fills the first screen under the bar, within reason: never
    // so small the timeline cannot be read, never so tall it has to scroll.
    final phoneHeight = (height - 160).clamp(560.0, 760.0);

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.s8,
        bottom: AppSpacing.s16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Pitch(wide: true),
                const SizedBox(height: AppSpacing.s8),
                ChapterList(controller: demo),
                const SizedBox(height: AppSpacing.s4),
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.s5),
                  child: Text(
                    context.l10n.landingDemoHint,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink3,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          SizedBox(
            height: phoneHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Positioned.fill(child: _Glow()),
                PhoneFrame(child: DemoApp(controller: demo)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The mark from the icon, blurred out behind the phone.
///
/// It is the only colour on the page that is not an action, and it is the
/// mark itself rather than a decoration picked to go with it.
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Opacity(
          opacity: 0.35,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: Image.asset(
              AppBrand.markAsset,
              package: 'app_ui',
              width: 620,
            ),
          ),
        ),
      ),
    );
  }
}

class _Pitch extends StatelessWidget {
  const _Pitch({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final headline = AppTypography.onest(
      size: wide ? 56 : 40,
      weight: FontWeight.w300,
      height: 1.1,
      tracking: -0.035,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.landingHeadline, style: headline),
        const SizedBox(height: AppSpacing.s6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            context.l10n.landingPitch(AppBrand.id),
            style: AppTypography.onest(
              size: wide ? 18 : 17,
              weight: FontWeight.w400,
              height: 1.65,
              color: AppColors.ink2,
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, thickness: 1, color: AppColors.line),
          const SizedBox(height: AppSpacing.s6),
          Text(title, style: AppTypography.label),
          const SizedBox(height: AppSpacing.s8),
          child,
        ],
      ),
    );
  }
}

/// [children] side by side when there is room, one under the other when not.
class _Columns extends StatelessWidget {
  const _Columns({required this.wide, required this.children});

  final bool wide;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s6),
              child: child,
            ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.s8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({required this.icon, required this.title, required this.text});

  final AppIconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(
          iconData: icon,
          color: AppColors.ink3,
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(title, style: AppTypography.title),
        const SizedBox(height: AppSpacing.s2),
        Text(text, style: AppTypography.label.copyWith(height: 1.65)),
      ],
    );
  }
}

class _Use extends StatelessWidget {
  const _Use(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.onest(
        size: 20,
        weight: FontWeight.w300,
        height: 1.45,
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final muted = AppTypography.caption.copyWith(color: AppColors.ink3);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // What PostHog records, said once, before anyone signs in.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              context.l10n.landingPrivacy,
              style: muted.copyWith(height: 1.6),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Image.asset(
                AppBrand.markAsset,
                package: 'app_ui',
                height: AppSpacing.s4,
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  context.l10n.landingFooter(AppBrand.id),
                  style: muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
