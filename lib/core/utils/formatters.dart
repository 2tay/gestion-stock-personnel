import 'package:intl/intl.dart';

/// Formatage centralisé : montants en MAD, dates FR, quantités.
///
/// Aucune feature ne doit appeler `NumberFormat`/`DateFormat` directement.
abstract final class Formatters {
  static const String locale = 'fr_FR';
  static const String currencySymbol = 'MAD';

  static final NumberFormat _decimal = NumberFormat('#,##0.##', locale);
  static final NumberFormat _amount = NumberFormat('#,##0.00', locale);
  static final NumberFormat _integer = NumberFormat('#,##0', locale);
  static final NumberFormat _percent = NumberFormat('#,##0.#', locale);

  static final DateFormat _date = DateFormat('dd/MM/yyyy', locale);
  static final DateFormat _dateShort = DateFormat('dd/MM', locale);
  static final DateFormat _time = DateFormat('HH:mm', locale);
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm', locale);
  static final DateFormat _dayLong = DateFormat('EEEE d MMMM yyyy', locale);

  /// `125 430,00 MAD`
  static String money(num value) => '${_amount.format(value)} $currencySymbol';

  /// `125 430,00` (sans devise, pour les colonnes où l'unité est en en-tête)
  static String amount(num value) => _amount.format(value);

  /// `+320 MAD` / `-1 250 MAD` — pour les écarts d'inventaire.
  static String signedMoney(num value) {
    final String sign = value > 0 ? '+' : '';
    return '$sign${_decimal.format(value)} $currencySymbol';
  }

  /// `95 kg`, `38 un.`
  static String quantity(num value, String unit) =>
      '${_decimal.format(value)} $unit';

  /// `+2 kg` / `-5 kg` — écarts de comptage.
  static String signedQuantity(num value, String unit) {
    final String sign = value > 0 ? '+' : '';
    return '$sign${_decimal.format(value)} $unit';
  }

  static String integer(num value) => _integer.format(value);

  /// `45 %`
  static String percent(num value) => '${_percent.format(value)} %';

  /// `30/05/2024`
  static String date(DateTime value) => _date.format(value);

  /// `30/05`
  static String dateShort(DateTime value) => _dateShort.format(value);

  /// `08:02`
  static String time(DateTime value) => _time.format(value);

  /// `30/05/2024 08:02`
  static String dateTime(DateTime value) => _dateTime.format(value);

  /// `jeudi 30 mai 2024`
  static String dayLong(DateTime value) => _dayLong.format(value);

  /// `04:28` — une durée présentée comme des heures travaillées.
  static String hours(Duration value) {
    final String h = value.inHours.toString().padLeft(2, '0');
    final String m = (value.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// `il y a 10 min`, `il y a 2 h`, `il y a 3 j`
  static String relative(DateTime value, {DateTime? now}) {
    final Duration diff = (now ?? DateTime.now()).difference(value);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 30) return 'il y a ${diff.inDays} j';
    return date(value);
  }

  /// Initiales pour les avatars : `Ahmed Benali` -> `AB`.
  static String initials(String fullName) {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters1();
    return '${parts.first.characters1()}${parts[1].characters1()}';
  }
}

extension on String {
  String characters1() => isEmpty ? '' : substring(0, 1).toUpperCase();
}
