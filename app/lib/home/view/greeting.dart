/// "Bom dia Pietro!", or without the name when there is not one yet.
String greeting(DateTime now, String? firstName) {
  final part = switch (now.hour) {
    >= 5 && < 12 => 'Bom dia',
    >= 12 && < 18 => 'Boa tarde',
    _ => 'Boa noite',
  };

  return firstName == null ? '$part!' : '$part $firstName!';
}

/// Portuguese dates, written out.
///
/// Doing this through `intl` would mean loading its locale data at startup
/// and still telling it how Brazilian Portuguese writes a date. Three lists
/// of names is less machinery, and only the home screen and its demo need
/// them.
abstract final class PtDate {
  static const _weekdays = <String>[
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  static const _months = <String>[
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  /// "Quarta-feira, 27 de agosto".
  static String long(DateTime at) {
    final weekday = _weekdays[at.weekday - DateTime.monday];
    final month = _months[at.month - 1];

    return '$weekday, ${at.day} de $month';
  }
}
