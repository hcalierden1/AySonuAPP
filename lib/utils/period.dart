import 'package:intl/intl.dart';

enum PeriodKind { daily, weekly, monthly }

extension PeriodKindLabel on PeriodKind {
  String get label => switch (this) {
        PeriodKind.daily => 'Günlük',
        PeriodKind.weekly => 'Haftalık',
        PeriodKind.monthly => 'Aylık',
      };
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// A day, a week (Monday–Sunday) or a calendar month.
class Period {
  final PeriodKind kind;
  final DateTime start;

  Period._(this.kind, this.start);

  factory Period.containing(PeriodKind kind, DateTime d) {
    switch (kind) {
      case PeriodKind.daily:
        return Period._(kind, dateOnly(d));
      case PeriodKind.weekly:
        return Period._(kind, DateTime(d.year, d.month, d.day - (d.weekday - 1)));
      case PeriodKind.monthly:
        return Period._(kind, DateTime(d.year, d.month, 1));
    }
  }

  /// Exclusive end.
  DateTime get end => switch (kind) {
        PeriodKind.daily => DateTime(start.year, start.month, start.day + 1),
        PeriodKind.weekly => DateTime(start.year, start.month, start.day + 7),
        PeriodKind.monthly => DateTime(start.year, start.month + 1, 1),
      };

  /// Number of days covered.
  int get dayCount => switch (kind) {
        PeriodKind.daily => 1,
        PeriodKind.weekly => 7,
        PeriodKind.monthly => DateTime(start.year, start.month + 1, 0).day,
      };

  Period shift(int n) => switch (kind) {
        PeriodKind.daily => Period._(
            kind, DateTime(start.year, start.month, start.day + n)),
        PeriodKind.weekly => Period._(
            kind, DateTime(start.year, start.month, start.day + 7 * n)),
        PeriodKind.monthly =>
          Period._(kind, DateTime(start.year, start.month + n, 1)),
      };

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  String get label {
    switch (kind) {
      case PeriodKind.daily:
        final today = dateOnly(DateTime.now());
        if (start == today) return 'Bugün';
        if (start == DateTime(today.year, today.month, today.day - 1)) {
          return 'Dün';
        }
        return DateFormat('d MMMM y, EEEE').format(start);
      case PeriodKind.weekly:
        final last = DateTime(start.year, start.month, start.day + 6);
        if (start.month == last.month) {
          return '${start.day} – ${DateFormat('d MMMM y').format(last)}';
        }
        if (start.year == last.year) {
          return '${DateFormat('d MMM').format(start)} – '
              '${DateFormat('d MMM y').format(last)}';
        }
        return '${DateFormat('d MMM y').format(start)} – '
            '${DateFormat('d MMM y').format(last)}';
      case PeriodKind.monthly:
        return DateFormat('MMMM y').format(start);
    }
  }
}

final money = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

/// Parses user input like "1.250,50", "1250.5" or "1250".
double? parseAmount(String input) {
  var s = input.trim().replaceAll(' ', '').replaceAll('₺', '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(s);
}
