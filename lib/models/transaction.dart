enum TxType { income, expense }

class Txn {
  final String id;
  final TxType type;
  final double amount;
  final String category;
  final String note;
  final DateTime date;

  /// Set when this record was booked automatically from a fixed monthly rule.
  final String? recurringId;

  const Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
    this.recurringId,
  });

  bool get isIncome => type == TxType.income;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        if (recurringId != null) 'recurringId': recurringId,
      };

  /// Throws (FormatException, TypeError, ArgumentError) if [j] is not a
  /// valid record.
  factory Txn.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final amount = (j['amount'] as num).toDouble();
    if (id.isEmpty) throw const FormatException('empty id');
    if (!amount.isFinite || amount < 0) {
      throw FormatException('invalid amount', amount);
    }
    return Txn(
      id: id,
      type: TxType.values.byName(j['type'] as String),
      amount: amount,
      category: j['category'] as String,
      note: (j['note'] as String?) ?? '',
      date: DateTime.parse(j['date'] as String),
      recurringId: j['recurringId'] as String?,
    );
  }
}
