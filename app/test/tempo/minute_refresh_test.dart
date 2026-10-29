import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunna/tempo/view/minute_refresh.dart';

void main() {
  group('MinuteRefresh', () {
    late int refreshes;

    Future<void> pumpAt(WidgetTester tester, Duration intoTheMinute) async {
      refreshes = 0;
      // Lands on a known point of the minute, whatever the fake clock's start.
      final now = clock.now();
      final start = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      );
      await tester.pump(
        start.add(intoTheMinute).difference(now) + const Duration(minutes: 1),
      );
      await tester.pumpWidget(MinuteRefresh(onRefresh: () => refreshes++));
    }

    void lifecycle(WidgetTester tester, List<AppLifecycleState> states) {
      for (final state in states) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    testWidgets('asks on each minute boundary, not a minute from now', (
      tester,
    ) async {
      await pumpAt(tester, const Duration(seconds: 40));

      await tester.pump(const Duration(seconds: 19));
      expect(refreshes, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(refreshes, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(refreshes, 2);
    });

    testWidgets('asks nothing while the app is hidden', (tester) async {
      await pumpAt(tester, const Duration(seconds: 40));

      lifecycle(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ]);
      await tester.pump(const Duration(minutes: 10));
      expect(refreshes, 0);

      lifecycle(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
    });

    testWidgets('asks once at once when shown again, then on the minute', (
      tester,
    ) async {
      await pumpAt(tester, const Duration(seconds: 40));

      lifecycle(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ]);
      await tester.pump(const Duration(minutes: 5, seconds: 5));
      lifecycle(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      expect(refreshes, 1);

      // Shown at :45 of a minute: the next ask is at its end, 15 s later.
      await tester.pump(const Duration(seconds: 14));
      expect(refreshes, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(refreshes, 2);
    });

    testWidgets('stops asking once it is gone', (tester) async {
      await pumpAt(tester, const Duration(seconds: 40));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 3));
      expect(refreshes, 0);
    });
  });
}
