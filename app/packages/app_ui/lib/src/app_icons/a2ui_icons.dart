import 'package:app_ui/src/app_icons/app_icon_data.dart';
import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// {@template a2ui_icons}
/// The icons an agent-composed message is allowed to draw.
///
/// The names are the other half of the server's `ICON_NAMES`: the server
/// rejects a name that is not on its list, and [resolve] returns null for a
/// name that is not on this one. Both halves have to be edited together, which
/// is deliberate. The alternative is a model picking a plausible-sounding icon
/// and the app drawing a question mark in the middle of a sentence.
/// {@endtemplate}
abstract final class A2uiIcons {
  /// Every name this app can draw, mapped to its glyph.
  static const _icons = <String, IconData>{
    // time
    'calendar': PhosphorIconsRegular.calendarBlank,

    'calendarPlus': PhosphorIconsRegular.calendarPlus,
    'calendarCheck': PhosphorIconsRegular.calendarCheck,
    'calendarX': PhosphorIconsRegular.calendarX,
    'clock': PhosphorIconsRegular.clock,
    'alarm': PhosphorIconsRegular.alarm,
    'timer': PhosphorIconsRegular.timer,
    'hourglass': PhosphorIconsRegular.hourglass,

    // status
    'check': PhosphorIconsBold.check,
    'checkCircle': PhosphorIconsFill.checkCircle,
    'x': PhosphorIconsBold.x,
    'xCircle': PhosphorIconsFill.xCircle,
    'warning': PhosphorIconsFill.warning,
    'info': PhosphorIconsFill.info,
    'question': PhosphorIconsRegular.question,
    'prohibit': PhosphorIconsRegular.prohibit,
    'spinner': PhosphorIconsRegular.spinner,

    // work
    'target': PhosphorIconsRegular.target,
    'flag': PhosphorIconsRegular.flag,
    'listChecks': PhosphorIconsRegular.listChecks,
    'checkSquare': PhosphorIconsRegular.checkSquare,
    'note': PhosphorIconsRegular.note,
    'notebook': PhosphorIconsRegular.notebook,
    'file': PhosphorIconsRegular.file,
    'folder': PhosphorIconsRegular.folder,
    'briefcase': PhosphorIconsRegular.briefcase,
    'chartLine': PhosphorIconsRegular.chartLine,
    'trophy': PhosphorIconsRegular.trophy,

    // objects
    'lightbulb': PhosphorIconsRegular.lightbulb,
    'sparkle': PhosphorIconsFill.sparkle,
    'star': PhosphorIconsFill.star,
    'heart': PhosphorIconsFill.heart,
    'fire': PhosphorIconsFill.fire,
    'rocket': PhosphorIconsRegular.rocket,
    'bell': PhosphorIconsRegular.bell,
    'bookmark': PhosphorIconsRegular.bookmarkSimple,
    'gift': PhosphorIconsRegular.gift,
    'coffee': PhosphorIconsRegular.coffee,
    'barbell': PhosphorIconsRegular.barbell,
    'moon': PhosphorIconsRegular.moon,
    'sun': PhosphorIconsRegular.sun,
    'cloud': PhosphorIconsRegular.cloud,

    // people and places
    'user': PhosphorIconsRegular.user,
    'users': PhosphorIconsRegular.users,
    'mapPin': PhosphorIconsRegular.mapPin,
    'house': PhosphorIconsRegular.house,
    'globe': PhosphorIconsRegular.globe,
    'envelope': PhosphorIconsRegular.envelope,
    'chat': PhosphorIconsRegular.chatCircle,
    'phone': PhosphorIconsRegular.phone,
    'video': PhosphorIconsRegular.videoCamera,

    // commerce
    'shoppingCart': PhosphorIconsRegular.shoppingCart,
    'currency': PhosphorIconsRegular.currencyCircleDollar,
    'creditCard': PhosphorIconsRegular.creditCard,

    // controls
    'plus': PhosphorIconsRegular.plus,
    'minus': PhosphorIconsRegular.minus,
    'pencil': PhosphorIconsRegular.pencilSimple,
    'trash': PhosphorIconsRegular.trash,
    'link': PhosphorIconsRegular.link,
    'magnifyingGlass': PhosphorIconsRegular.magnifyingGlass,
    'gear': PhosphorIconsRegular.gear,
    'arrowRight': PhosphorIconsRegular.arrowRight,
    'arrowLeft': PhosphorIconsRegular.arrowLeft,
    'arrowUp': PhosphorIconsRegular.arrowUp,
    'caretRight': PhosphorIconsRegular.caretRight,
    'dotsThree': PhosphorIconsRegular.dotsThree,
  };

  /// The icon for [name], or null when the app does not know it.
  static AppIconData? resolve(String? name) {
    final icon = _icons[name];
    return icon == null ? null : AppIconData.phosphor(icon);
  }

  /// Every name this app can draw. Used by the catalog test.
  static Iterable<String> get names => _icons.keys;
}
