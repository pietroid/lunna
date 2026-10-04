import 'dart:math' as math;

import 'package:app_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// The colour of a day, hour by hour.
///
/// This is the one place in the app where colour is decorative rather than
/// semantic, and it earns that by being literal: the ring around the clock is
/// the light outside. It opens pale and warm at seven, burns orange through
/// midday, washes back to white in the late afternoon, and falls through blue
/// into near-black as ten at night approaches.
///
/// The waking day is the only part drawn. Before [startHour] the ring is
/// empty and after [endHour] it is full, so the clock never claims progress
/// through hours the user was not going to spend anyway.
abstract final class AppDay {
  /// When the ring starts filling. 07:00.
  static const startHour = 7.0;

  /// When the ring is full. 22:00.
  static const endHour = 22.0;

  /// The ramp, as (hour, colour) stops in ascending order.
  static const _stops = <(double, Color)>[
    (7, Color(0xFFFEFCDD)),
    (9, Color(0xFFFFD98A)),
    (12, Color(0xFFF88A33)),
    (15, Color(0xFFFFC08A)),
    (18, Color(0xFFF5F5F5)),
    (20, Color(0xFF4E6BD6)),
    (22, Color(0xFF101B4A)),
  ];

  /// How far through the waking day [at] is, from 0 to 1.
  static double progressAt(DateTime at) {
    final hour = at.hour + at.minute / 60 + at.second / 3600;

    return ((hour - startHour) / (endHour - startHour)).clamp(0.0, 1.0);
  }

  /// The light at [at].
  static Color colorAt(DateTime at) {
    return colorAtHour(at.hour + at.minute / 60);
  }

  /// The light at [hour], where 13.5 is half past one in the afternoon.
  static Color colorAtHour(double hour) {
    final clamped = hour.clamp(_stops.first.$1, _stops.last.$1);

    for (var index = 0; index < _stops.length - 1; index++) {
      final (fromHour, fromColor) = _stops[index];
      final (toHour, toColor) = _stops[index + 1];
      if (clamped > toHour) continue;

      final t = (clamped - fromHour) / (toHour - fromHour);

      return Color.lerp(fromColor, toColor, t) ?? fromColor;
    }

    return _stops.last.$2;
  }

  /// The colour the ring has reached at [progress], from 0 to 1.
  static Color colorAtProgress(double progress) {
    return colorAtHour(
      startHour + (endHour - startHour) * progress.clamp(0.0, 1.0),
    );
  }

  /// The ramp sampled evenly, for a gradient that has to be given a list.
  ///
  /// [count] samples rather than the seven stops, because the stops are not
  /// evenly spaced in time and a gradient given uneven stops as if they were
  /// even would bend every hour on the ring.
  static List<Color> ramp({int count = 24, double upTo = 1}) {
    final last = upTo.clamp(0.0, 1.0);

    return List<Color>.generate(count, (index) {
      return colorAtProgress(last * index / math.max(1, count - 1));
    });
  }

  /// The colour of the part of the ring the day has not reached yet.
  static Color get unfilled => AppColors.fillStrong;
}
