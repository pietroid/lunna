import 'package:app_ui/src/theme/app_brand.dart';
import 'package:flutter/material.dart';

/// The color tokens, one set per [Brand].
///
/// **Focus** is a dark-only app built on true black, so the screen disappears
/// and only the content is lit. Surfaces are opaque greys rather than
/// translucent whites: on black a translucent white lifts the hue of whatever
/// sits behind it, and the app leans on a single neutral ramp.
///
/// **Lunna** is the same app in daylight: white, warm neutrals with a trace
/// of rose in them, a red accent, routines in a pale blue. Every token keeps
/// its meaning; only the values change, so no screen knows which app it is.
///
/// Against either ramp sits a five-colour palette, and every one of them
/// means something. Colour in this app is reserved for what can be acted on
/// or what carries a state: a button, an icon that says how something went, a
/// caption that is a warning. Nothing is coloured to be pretty, because once
/// anything is, nothing is legible at a glance.
abstract final class AppColors {
  /// The page background behind every screen. True black.
  static const bg = AppBrand.isLunna ? Color(0xFFFFFFFF) : Color(0xFF000000);

  /// The surface a sheet, a menu, or a dialog sits on.
  static const surface = AppBrand.isLunna
      ? Color(0xFFFFFFFF)
      : Color(0xFF0D0D0D);

  /// The borderless fill that gives a field or a card its shape.
  static const fill = AppBrand.isLunna ? Color(0xFFF7F3F3) : Color(0xFF1C1C1C);

  /// A heavier [fill], for pressed states, tracks, and inactive bars.
  static const fillStrong = AppBrand.isLunna
      ? Color(0xFFEEE7E8)
      : Color(0xFF2B2B2B);

  /// Hairline separators.
  static const line = AppBrand.isLunna ? Color(0xFFEEE7E8) : Color(0xFF232323);

  /// Text primary: the lit content.
  static const ink = AppBrand.isLunna ? Color(0xFF1C1517) : Color(0xFFF5F5F5);

  /// Text secondary: labels, captions, and subtitles.
  static const ink2 = AppBrand.isLunna ? Color(0xFF6F6468) : Color(0xFFA1A1A1);

  /// Text tertiary: placeholders and disabled content.
  static const ink3 = AppBrand.isLunna ? Color(0xFFA89DA1) : Color(0xFF6B6B6B);

  /// The accent: pale lime on Focus, red on Lunna. The one colour that says
  /// "this is the thing to tap". On either page it is the loudest thing on
  /// screen, so it is spent carefully: one primary action per view.
  static const accent = AppBrand.isLunna
      ? Color(0xFFE2394F)
      : Color(0xFFEEFFBB);

  /// Content drawn on top of [accent]: black on the lime, white on the red.
  static const onAccent = AppBrand.isLunna
      ? Color(0xFFFFFFFF)
      : Color(0xFF000000);

  /// A 14% accent tint, for accent-washed fills.
  static const accentSoft = AppBrand.isLunna
      ? Color(0x24E2394F)
      : Color(0x24EEFFBB);

  /// A 7% accent tint: the quietest wash, behind what the agent offers
  /// without being asked.
  static const accentWash = AppBrand.isLunna
      ? Color(0x12E2394F)
      : Color(0x12EEFFBB);

  /// Done, free, available, confirmed.
  static const success = AppBrand.isLunna
      ? Color(0xFF0E8F68)
      : Color(0xFF00B481);

  /// Neutral context: something true but not an outcome.
  ///
  /// The deep navy is too dark to read as text on black, so [infoInk] is what
  /// text and icons use, and this stays for fills and borders.
  static const info = AppBrand.isLunna ? Color(0xFFEEF0F9) : Color(0xFF1B318F);

  /// A lifted [info], legible as text and icons on the black background.
  static const infoInk = AppBrand.isLunna
      ? Color(0xFF4B5AA6)
      : Color(0xFF7C92E8);

  /// Blocked, failed, destructive.
  static const danger = AppBrand.isLunna
      ? Color(0xFFFCE5E8)
      : Color(0xFF9E2B3D);

  /// A lifted [danger], legible as text and icons on the black background.
  static const dangerInk = AppBrand.isLunna
      ? Color(0xFFB4243A)
      : Color(0xFFE8697C);

  /// Needs attention, but nothing has gone wrong yet.
  static const warning = AppBrand.isLunna
      ? Color(0xFFD9603A)
      : Color(0xFFFF9A6B);

  /// The time a delivery has used, in its pace bar: always red, the red of
  /// a clock running. Lunna's accent; on Focus, whose accent is lime, the
  /// lifted [danger].
  static const paceTime = AppBrand.isLunna
      ? Color(0xFFE2394F)
      : Color(0xFFE8697C);

  /// The work a delivery has done, drawn over [paceTime] in the same bar:
  /// always green, so green covering the red reads as ahead and red showing
  /// past it as behind. On Lunna a fresh emerald, as light as the red so the
  /// two weigh the same beside the rose neutrals; on Focus [success].
  static const paceDone = AppBrand.isLunna
      ? Color(0xFF1FA37A)
      : Color(0xFF00B481);

  /// The fill behind a delivery that is late: [fill] with a little red in
  /// it, so the card reads as urgent before its tag is read.
  static const urgentFill = AppBrand.isLunna
      ? Color(0xFFFDEDEF)
      : Color(0xFF2A1418);

  /// The fill behind a block a routine puts on every day.
  ///
  /// One of the two fills that is not a state. Lunch and the morning routine
  /// are the same blocks every day, and the calendar should tell them apart
  /// from what was written down this morning without being read: on Focus a
  /// deep navy from the [info] family, plain enough beside [fill] to see at a
  /// glance and still darker than anything that asks to be tapped; on Lunna
  /// the same blue, washed out to a pale tint.
  static const routineFill = AppBrand.isLunna
      ? Color(0xFFEEF0F9)
      : Color(0xFF17204A);

  /// Marks and hours on [routineFill].
  static const routineInk = AppBrand.isLunna
      ? Color(0xFF4B5AA6)
      : Color(0xFF9AABEF);

  /// The fill behind a fixed block: a meeting, a day of a fixed routine,
  /// anything whose hour is the point of it.
  ///
  /// Nothing moves these, and everything else flows around them, so the
  /// calendar shows them as the walls of the day: a warm sand, apart from
  /// the routines' blue and the accent's red, washed pale on Lunna and
  /// deepened to a dark umber on Focus.
  static const fixedFill = AppBrand.isLunna
      ? Color(0xFFFBF1E6)
      : Color(0xFF2A1D10);

  /// Marks and hours on [fixedFill].
  static const fixedInk = AppBrand.isLunna
      ? Color(0xFFA0602A)
      : Color(0xFFE5B27F);

  /// The fill behind a stretch of the day with nothing on it.
  ///
  /// The other one, quieter than any card, so free time reads as room to
  /// breathe rather than as one more thing on the list: a faint green off
  /// black on Focus, and nothing at all on Lunna, where [freeEdge] alone
  /// draws the room.
  static const freeFill = AppBrand.isLunna
      ? Color(0x00FFFFFF)
      : Color(0xFF101A16);

  /// Text on [freeFill].
  static const freeInk = AppBrand.isLunna
      ? Color(0xFFA89DA1)
      : Color(0xFF7FA496);

  /// The shadow under something that floats over the page: deep on black,
  /// where it barely shows, and a light warm ink on Lunna's white.
  static const shadow = AppBrand.isLunna
      ? Color(0x401C1517)
      : Color(0x99000000);

  /// The hairline around a free stretch. Focus needs none: its [freeFill]
  /// already gives the room its shape.
  static const freeEdge = AppBrand.isLunna
      ? Color(0xFFEEE7E8)
      : Color(0x00000000);

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
