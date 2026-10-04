import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDay', () {
    test('fills only between seven in the morning and ten at night', () {
      expect(AppDay.progressAt(DateTime(2026, 1, 1, 6)), 0);
      expect(AppDay.progressAt(DateTime(2026, 1, 1, 7)), 0);
      expect(AppDay.progressAt(DateTime(2026, 1, 1, 14, 30)), 0.5);
      expect(AppDay.progressAt(DateTime(2026, 1, 1, 22)), 1);
      expect(AppDay.progressAt(DateTime(2026, 1, 1, 23, 59)), 1);
    });

    test('opens warm and white, burns orange, and ends dark blue', () {
      final morning = AppDay.colorAtHour(7);
      final noon = AppDay.colorAtHour(12);
      final evening = AppDay.colorAtHour(18);
      final night = AppDay.colorAtHour(22);

      // Warm and near-white at seven.
      expect(morning.r, greaterThan(0.9));
      expect(morning.b, greaterThan(0.8));

      // Orange at midday: red well ahead of blue.
      expect(noon.r - noon.b, greaterThan(0.5));

      // Back to white at six.
      expect((evening.r - evening.b).abs(), lessThan(0.05));

      // Dark blue by ten: blue ahead of red, and everything is dim.
      expect(night.b, greaterThan(night.r));
      expect(night.r + night.g + night.b, lessThan(1));
    });
  });
}
