import 'transaction.dart';

/// Month index used to remember which months were already booked.
int ymOf(DateTime d) => d.year * 12 + d.month - 1;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// A fixed monthly income/expense, e.g. "salary on the 5th" or
/// "rent on the 15th". It is booked as a real transaction only when its day
/// arrives, so it never affects the balance in advance.
class RecurringRule {
  final String id;
  final TxType type;
  final double amount;
  final String category;
  final String note;

  /// Day of month (1–31). Short months use their last day instead.
  final int day;

  /// Occurrences before this day are never booked.
  final DateTime createdAt;

  /// Last month (see [ymOf]) that has been booked, if any.
  final int? lastYm;

  const RecurringRule({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.day,
    required this.createdAt,
    this.note = '',
    this.lastYm,
  });

  bool get isIncome => type == TxType.income;

  DateTime occurrenceIn(int ym) {
    final y = ym ~/ 12, m = ym % 12 + 1;
    final last = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, day > last ? last : day);
  }

  /// Whether the occurrence of month [ym] still has to be booked.
  bool isPending(int ym) =>
      (lastYm == null || ym > lastYm!) &&
      !occurrenceIn(ym).isBefore(_dateOnly(createdAt));

  /// Next date this rule will be booked on, counting from [now].
  DateTime nextOccurrence(DateTime now) {
    var ym = ymOf(now);
    while (true) {
      final d = occurrenceIn(ym);
      if (!d.isBefore(_dateOnly(now)) && isPending(ym)) return d;
      ym++;
    }
  }

  RecurringRule copyWith({int? lastYm}) => RecurringRule(
        id: id,
        type: type,
        amount: amount,
        category: category,
        note: note,
        day: day,
        createdAt: createdAt,
        lastYm: lastYm ?? this.lastYm,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
        'day': day,
        'createdAt': createdAt.toIso8601String(),
        if (lastYm != null) 'lastYm': lastYm,
      };

  factory RecurringRule.fromJson(Map<String, dynamic> j) => RecurringRule(
        id: j['id'] as String,
        type: TxType.values.byName(j['type'] as String),
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] as String,
        note: (j['note'] as String?) ?? '',
        day: j['day'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
        lastYm: j['lastYm'] as int?,
      );
}

/// A not-yet-booked occurrence, shown as "planned" in the UI.
class PlannedItem {
  final RecurringRule rule;
  final DateTime date;
  const PlannedItem(this.rule, this.date);
}
