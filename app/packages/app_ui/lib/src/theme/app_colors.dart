import 'package:flutter/material.dart';

/// The color tokens.
///
/// Lunna is drawn in daylight: white, warm neutrals with a trace of rose in
/// them, a red accent, routines in a pale blue.
///
/// Against that ramp sits a five-colour palette, and every one of them
/// means something. Colour in this app is reserved for what can be acted on
/// or what carries a state: a button, an icon that says how something went, a
/// caption that is a warning. Nothing is coloured to be pretty, because once
/// anything is, nothing is legible at a glance.
abstract final class AppColors {
  /// The page background behind every screen. White.
  static const bg = Color(0xFFFFFFFF);

  /// The surface a sheet, a menu, or a dialog sits on.
  static const surface = Color(0xFFFFFFFF);

  /// The borderless fill that gives a field or a card its shape.
  static const fill = Color(0xFFF7F3F3);

  /// A heavier [fill], for pressed states, tracks, and inactive bars.
  static const fillStrong = Color(0xFFEEE7E8);

  /// Hairline separators.
  static const line = Color(0xFFEEE7E8);

  /// Text primary: the lit content.
  static const ink = Color(0xFF1C1517);

  /// Text secondary: labels, captions, and subtitles.
  static const ink2 = Color(0xFF6F6468);

  /// Text tertiary: placeholders and disabled content.
  static const ink3 = Color(0xFFA89DA1);

  /// The accent, red. The one colour that says "this is the thing to tap".
  /// It is the loudest thing on screen, so it is spent carefully: one
  /// primary action per view.
  static const accent = Color(0xFFE2394F);

  /// Content drawn on top of [accent]: white on the red.
  static const onAccent = Color(0xFFFFFFFF);

  /// A 14% accent tint, for accent-washed fills.
  static const accentSoft = Color(0x24E2394F);

  /// A 7% accent tint: the quietest wash, behind what the agent offers
  /// without being asked.
  static const accentWash = Color(0x12E2394F);

  /// Done, free, available, confirmed.
  static const success = Color(0xFF0E8F68);

  /// Neutral context: something true but not an outcome.
  ///
  /// A pale blue, too light to read as text, so [infoInk] is what text and
  /// icons use, and this stays for fills and borders.
  static const info = Color(0xFFEEF0F9);

  /// A deeper [info], legible as text and icons on the white page.
  static const infoInk = Color(0xFF4B5AA6);

  /// Blocked, failed, destructive.
  static const danger = Color(0xFFFCE5E8);

  /// A deeper [danger], legible as text and icons on the white page.
  static const dangerInk = Color(0xFFB4243A);

  /// Needs attention, but nothing has gone wrong yet.
  static const warning = Color(0xFFD9603A);

  /// The time a delivery has used, in its pace bar: always red, the red of
  /// a clock running: the accent.
  static const paceTime = Color(0xFFE2394F);

  /// The work a delivery has done, drawn over [paceTime] in the same bar:
  /// always green, so green covering the red reads as ahead and red showing
  /// past it as behind. A fresh emerald, as light as the red so the two weigh
  /// the same beside the rose neutrals.
  static const paceDone = Color(0xFF1FA37A);

  /// The piece of a task at work right now, in its pace bar (#92): a short
  /// yellow run right after the [paceDone] green, as long as that piece's
  /// minutes, so what is being done reads as on its way to green.
  static const paceDoing = Color(0xFFF2B705);

  /// The fill behind a delivery that is late: [fill] with a little red in
  /// it, so the card reads as urgent before its tag is read.
  static const urgentFill = Color(0xFFFDEDEF);

  /// The fill behind a block a routine puts on every day.
  ///
  /// One of the two fills that is not a state. Lunch and the morning routine
  /// are the same blocks every day, and the calendar should tell them apart
  /// from what was written down this morning without being read: the [info]
  /// blue, washed out to a pale tint.
  static const routineFill = Color(0xFFEEF0F9);

  /// Marks and hours on [routineFill].
  static const routineInk = Color(0xFF4B5AA6);

  /// The fill behind a fixed block: a meeting, a day of a fixed routine,
  /// anything whose hour is the point of it.
  ///
  /// Nothing moves these, and everything else flows around them, so the
  /// calendar shows them as the walls of the day: a warm sand, apart from
  /// the routines' blue and the accent's red, washed pale.
  static const fixedFill = Color(0xFFFBF1E6);

  /// Marks and hours on [fixedFill].
  static const fixedInk = Color(0xFFA0602A);

  /// The fill behind a stretch of the day with nothing on it.
  ///
  /// The other one, quieter than any card, so free time reads as room to
  /// breathe rather than as one more thing on the list: nothing at all, so
  /// [freeEdge] alone draws the room.
  static const freeFill = Color(0x00FFFFFF);

  /// Text on [freeFill].
  static const freeInk = Color(0xFFA89DA1);

  /// The shadow under something that floats over the page: a light warm ink.
  static const shadow = Color(0x401C1517);

  /// The hairline around a free stretch, which has no fill of its own.
  static const freeEdge = Color(0xFFEEE7E8);

  /// The period on the cycle: the accent's red, the phase that asks for the
  /// least work. Marks and text; its fill is [cycleMenstrualFill].
  static const cycleMenstrual = Color(0xFFE2394F);

  /// The fill behind [cycleMenstrual].
  static const cycleMenstrualFill = Color(0xFFFDEDEF);

  /// The follicular phase, energy coming back: a rose, between the period's
  /// red and the luteal lilac.
  static const cycleFollicular = Color(0xFFB4467F);

  /// The fill behind [cycleFollicular].
  static const cycleFollicularFill = Color(0xFFF9ECF3);

  /// Ovulation, the peak: a warm amber, the sun of its icon.
  static const cycleOvulatory = Color(0xFFB86A12);

  /// The fill behind [cycleOvulatory].
  static const cycleOvulatoryFill = Color(0xFFFFF3E2);

  /// The luteal phase, winding down: a lilac, the moon of its icon.
  static const cycleLuteal = Color(0xFF6B57B0);

  /// The fill behind [cycleLuteal].
  static const cycleLutealFill = Color(0xFFF1EEF9);

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
