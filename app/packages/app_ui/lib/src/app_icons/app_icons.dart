import 'package:app_ui/src/app_icons/app_icon_data.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// {@template app_icons}
/// A collection of app icons used throughout the application.
///
/// Icons default to Phosphor; SVG assets are kept only for brand logos
/// that are not available in the Phosphor set.
/// {@endtemplate}
class AppIcons {
  /// Google Icon (SVG asset).
  static const google = AppIconData.asset('google');

  /// Pen Icon.
  static const pen = AppIconData.phosphor(PhosphorIconsRegular.pen);

  /// Home Icon.
  static const home = AppIconData.phosphor(PhosphorIconsRegular.house);

  /// Settings Icon.
  static const settings = AppIconData.phosphor(PhosphorIconsRegular.gear);

  /// Logout Icon.
  static const logout = AppIconData.phosphor(PhosphorIconsRegular.signOut);

  /// Send Icon, for submitting a prompt.
  ///
  /// The paper plane rather than an arrow in a filled circle: the sheet's
  /// send sits inside the field, where a solid disc would be the loudest
  /// thing on a black screen.
  static const send = AppIconData.phosphor(PhosphorIconsFill.paperPlaneRight);

  /// Back Icon.
  static const back = AppIconData.phosphor(PhosphorIconsRegular.arrowLeft);

  /// Check, for something that has been closed out.
  ///
  /// The bare mark, not a check in a circle: the disc is a second shape doing
  /// no work, and on a screen this quiet it reads as a button that is not one.
  static const check = AppIconData.phosphor(PhosphorIconsBold.check);

  /// Chevron, for a row that opens something.
  static const chevronRight = AppIconData.phosphor(
    PhosphorIconsRegular.caretRight,
  );

  /// Time, the day as it happened and as it is still going to happen.
  static const time = AppIconData.phosphor(PhosphorIconsRegular.clock);

  /// Things, what outlives a single day.
  static const things = AppIconData.phosphor(PhosphorIconsRegular.folders);

  /// Recommendations, what the agent puts forward on its own.
  static const recommendations = AppIconData.phosphor(
    PhosphorIconsRegular.lightbulb,
  );

  /// Menu, everything that is not one of the three lists.
  static const menu = AppIconData.phosphor(PhosphorIconsRegular.list);

  /// Archive, for what has been put away rather than finished.
  static const archive = AppIconData.phosphor(PhosphorIconsRegular.archive);

  /// Calendar, for a card that came off the calendar rather than out of a
  /// conversation.
  static const calendar = AppIconData.phosphor(
    PhosphorIconsRegular.calendarBlank,
  );

  /// Warning, for a screen that is older than the user thinks it is.
  static const warning = AppIconData.phosphor(PhosphorIconsRegular.warning);

  /// Pin, for a card whose hour is the point of it.
  static const pin = AppIconData.phosphor(PhosphorIconsRegular.pushPin);

  /// Timer, for how long something takes.
  static const timer = AppIconData.phosphor(PhosphorIconsRegular.timer);

  /// Undo, for taking a finished thread back out of the concluded list.
  static const undo = AppIconData.phosphor(
    PhosphorIconsRegular.arrowCounterClockwise,
  );

  /// Stops the running block without finishing it.
  static const pause = AppIconData.phosphor(PhosphorIconsFill.pause);

  /// Runs a paused block again.
  static const play = AppIconData.phosphor(PhosphorIconsFill.play);

  /// Adds time.
  static const plus = AppIconData.phosphor(PhosphorIconsRegular.plus);

  /// Takes something away for good.
  static const trash = AppIconData.phosphor(PhosphorIconsRegular.trash);

  /// Opens a conversation.
  static const chat = AppIconData.phosphor(PhosphorIconsRegular.chatCircle);

  /// Conversations, every thread the user has.
  static const conversations = AppIconData.phosphor(
    PhosphorIconsRegular.chatsCircle,
  );

  /// A routine, a block that comes back every day.
  static const repeat = AppIconData.phosphor(PhosphorIconsRegular.repeat);

  /// Moves a thing onto the timeline.
  static const prioritize = AppIconData.phosphor(
    PhosphorIconsRegular.calendarPlus,
  );
}
