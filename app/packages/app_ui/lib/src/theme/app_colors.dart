import 'package:flutter/material.dart';

/// The color tokens for Focus.
///
/// Focus is a dark-only app built on true black, so the screen disappears and
/// only the content is lit. Surfaces are opaque greys rather than translucent
/// whites: on black a translucent white lifts the hue of whatever sits behind
/// it, and the app leans on a single neutral ramp.
///
/// Against that ramp sits a five-colour palette, and every one of them means
/// something. Colour in this app is reserved for what can be acted on or what
/// carries a state: a button, an icon that says how something went, a caption
/// that is a warning. Nothing is coloured to be pretty, because once anything
/// is, nothing is legible at a glance.
abstract final class AppColors {
  /// The page background behind every screen. True black.
  static const bg = Color(0xFF000000);

  /// The surface a sheet, a menu, or a dialog sits on.
  static const surface = Color(0xFF0D0D0D);

  /// The borderless fill that gives a field or a card its shape.
  static const fill = Color(0xFF1C1C1C);

  /// A heavier [fill], for pressed states, tracks, and inactive bars.
  static const fillStrong = Color(0xFF2B2B2B);

  /// Hairline separators.
  static const line = Color(0xFF232323);

  /// Text primary: the lit content.
  static const ink = Color(0xFFF5F5F5);

  /// Text secondary: labels, captions, and subtitles.
  static const ink2 = Color(0xFFA1A1A1);

  /// Text tertiary: placeholders and disabled content.
  static const ink3 = Color(0xFF6B6B6B);

  /// The accent: pale lime. The one colour that says "this is the thing to
  /// tap". On true black it is the brightest thing on screen, so it is spent
  /// carefully: one primary action per view.
  static const accent = Color(0xFFEEFFBB);

  /// Content drawn on top of [accent]. The lime is light, so this is black.
  static const onAccent = Color(0xFF000000);

  /// A 14% accent tint, for accent-washed fills.
  static const accentSoft = Color(0x24EEFFBB);

  /// Done, free, available, confirmed.
  static const success = Color(0xFF00B481);

  /// Neutral context: something true but not an outcome.
  ///
  /// The deep navy is too dark to read as text on black, so [infoInk] is what
  /// text and icons use, and this stays for fills and borders.
  static const info = Color(0xFF1B318F);

  /// A lifted [info], legible as text and icons on the black background.
  static const infoInk = Color(0xFF7C92E8);

  /// Blocked, failed, destructive.
  static const danger = Color(0xFF9E2B3D);

  /// A lifted [danger], legible as text and icons on the black background.
  static const dangerInk = Color(0xFFE8697C);

  /// Needs attention, but nothing has gone wrong yet.
  static const warning = Color(0xFFFF9A6B);

  /// The fill behind a block a routine puts on every day.
  ///
  /// One of the two fills that is not a state. Lunch and the morning routine
  /// are the same blocks every day, and telling them apart from what was
  /// written down this morning at a glance is worth a faint cool shift off
  /// [fill], and no more than that.
  static const routineFill = Color(0xFF1A1E27);

  /// The fill behind a stretch of the day with nothing on it.
  ///
  /// The other one: a faint green off black, quieter than any card, so free
  /// time reads as room to breathe rather than as one more thing on the list.
  static const freeFill = Color(0xFF101A16);

  /// Text on [freeFill].
  static const freeInk = Color(0xFF7FA496);

  /// Positive / success. Retained as the semantic name used by older widgets.
  static const Color positive = success;

  /// Negative / error. Retained as the semantic name used by older widgets.
  static const Color negative = dangerInk;

  /// The colour for a role, as the agent names it.
  ///
  /// The agent picks a role and never a hex, so the palette can change here
  /// without touching a prompt or rewriting a thread that has already been
  /// stored. An unknown role falls back to [ink] rather than to nothing, so a
  /// new role added on the server degrades to readable text.
  static Color forRole(String? role) {
    return switch (role) {
      'accent' => accent,
      'success' => success,
      'info' => infoInk,
      'warning' => warning,
      'danger' => dangerInk,
      'ink' => ink,
      'ink2' => ink2,
      'ink3' => ink3,
      _ => ink,
    };
  }

  /// The fill behind a surface tinted by [role], at 12% opacity.
  static Color washForRole(String? role) {
    return forRole(role).withValues(alpha: 0.12);
  }

  /// The border for a surface tinted by [role], at 32% opacity.
  static Color borderForRole(String? role) {
    return forRole(role).withValues(alpha: 0.32);
  }
}
