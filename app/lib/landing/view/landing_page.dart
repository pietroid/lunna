import 'dart:ui';

import 'package:app_ui/app_ui.dart';
import 'package:auth/auth.dart';
import 'package:focus/demo/demo.dart';
import 'package:focus/landing/widgets/phone_frame.dart';

/// {@template landing_page}
/// What someone who is not signed in sees: what Focus is, with the app itself
/// running in a phone beside it.
///
/// It is drawn inside an [AuthScreen], and signing in is one quiet word in
/// the corner. The page is there to be read, and the person it lets in
/// already knows where to tap.
///
/// The page is in English, unlike the rest of the app: it is read by people
/// who have not met Focus yet. The app in the phone stays in Portuguese,
/// because it is the app as it ships.
///
/// On a narrow screen there is no phone. The screen already is one, and a
/// phone drawn inside it would be a thumbnail.
/// {@endtemplate}
class LandingPage extends StatelessWidget {
  /// {@macro landing_page}
  const LandingPage({super.key});

  /// Below this width the page is one column and the phone is left out.
  static const _wide = 960.0;

  static const _maxWidth = 1160.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wide;
        final gutter = wide ? AppSpacing.s12 : AppSpacing.s6;

        return SingleChildScrollView(
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
                        _WideHero(height: constraints.maxHeight)
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.s12,
                          ),
                          child: _Pitch(wide: false),
                        ),
                      _Section(
                        title: 'How it is built',
                        child: _Columns(
                          wide: wide,
                          children: const [
                            _Part(
                              number: '01',
                              title: 'The app',
                              text:
                                  'The control center. The same app on '
                                  'iPhone, Android and the web.',
                            ),
                            _Part(
                              number: '02',
                              title: 'The server',
                              text:
                                  'Talks to the app and to the agent, and '
                                  'keeps every conversation in its place.',
                            ),
                            _Part(
                              number: '03',
                              title: 'The agent',
                              text:
                                  'Autonomous and sandboxed. It connects to '
                                  'any tool and does whatever the job '
                                  'needs.',
                            ),
                          ],
                        ),
                      ),
                      const _Section(
                        title: 'Integrations',
                        child: Column(
                          children: [
                            _Row(
                              title: 'Google Calendar',
                              text:
                                  'A Google account that belongs to Focus '
                                  'alone. Its calendar, and yours untouched.',
                            ),
                            _Row(
                              title: 'GitHub',
                              text:
                                  'The agent can change the code of Focus '
                                  'itself and ship a new version.',
                            ),
                            _Row(
                              title: 'Web search',
                              text:
                                  'When the answer is not at home, it goes '
                                  'looking.',
                            ),
                            _Row(
                              title: 'OpenRouter',
                              text:
                                  'Picks the model for each request, with '
                                  'no lock-in to a single provider.',
                            ),
                          ],
                        ),
                      ),
                      _Section(
                        title: 'Day to day',
                        child: _Columns(
                          wide: wide,
                          children: const [
                            _Use('Write down what needs doing.'),
                            _Use('Give every task its hour.'),
                            _Use(
                              'Ask anything, of any model.',
                            ),
                            _Use('Look after agents, tokens and accounts.'),
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
          Image.asset('assets/images/icon.png', height: 38),
          const SizedBox(width: AppSpacing.s3),
          Text(
            'Focus',
            style: AppTypography.onest(
              size: 32,
              weight: FontWeight.w500,
              tracking: -0.02,
            ),
          ),
          const Spacer(),
          const AuthSignInButton(compact: true, label: 'Sign in'),
        ],
      ),
    );
  }
}

/// The pitch on the left, the phone on the right, filling the first screen.
class _WideHero extends StatelessWidget {
  const _WideHero({required this.height});

  /// The height of the window, which the phone is sized against.
  final double height;

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
          const Expanded(child: _Pitch(wide: true)),
          const SizedBox(width: AppSpacing.s16),
          SizedBox(
            height: phoneHeight,
            child: const Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: _Glow()),
                PhoneFrame(child: DemoApp()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The orb from the icon, blurred out behind the phone.
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
            child: Image.asset('assets/images/icon.png', width: 620),
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
      size: wide ? 68 : 44,
      weight: FontWeight.w300,
      height: 1.1,
      tracking: -0.035,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lock-in and relax.', style: headline),
        const SizedBox(height: AppSpacing.s6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'Focus is a domestic and personal organization system. '
            'Write what you need, paste '
            'a link or just ask. Focus will organize your day and help you '
            'do what you need.',
            style: AppTypography.onest(
              size: wide ? 19 : 17,
              weight: FontWeight.w400,
              height: 1.65,
              color: AppColors.ink2,
            ),
          ),
        ),
        if (wide) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            'The phone beside this is the real app. Tap the orb to schedule '
            'something, or a block to open it.',
            style: AppTypography.caption.copyWith(
              color: AppColors.ink3,
              height: 1.6,
            ),
          ),
        ],
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
  const _Part({required this.number, required this.title, required this.text});

  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: AppTypography.caption.copyWith(
            color: AppColors.ink3,
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(title, style: AppTypography.title),
        const SizedBox(height: AppSpacing.s2),
        Text(text, style: AppTypography.label.copyWith(height: 1.65)),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final name = Text(title, style: AppTypography.bodyStrong);
          final body = Text(
            text,
            style: AppTypography.label.copyWith(height: 1.65),
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                name,
                const SizedBox(height: AppSpacing.s1),
                body,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 240, child: name),
              Expanded(child: body),
            ],
          );
        },
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Row(
        children: [
          Image.asset('assets/images/icon.png', height: AppSpacing.s4),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              'Focus · Informational human organicity',
              style: AppTypography.caption.copyWith(color: AppColors.ink3),
            ),
          ),
        ],
      ),
    );
  }
}
