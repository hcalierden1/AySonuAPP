import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recurring.dart';
import '../models/transaction.dart';

/// Keeps all transactions and fixed monthly rules in memory and persists them
/// on the device.
///
/// Records can also be written from the notification shade (a separate
/// background isolate), so every mutation first re-reads the latest data
/// from disk to avoid overwriting entries added elsewhere.
class TransactionStore extends ChangeNotifier {
  static const _key = 'transactions_v1';
  static const _rulesKey = 'recurring_v1';

  TransactionStore({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final List<Txn> _items = [];
  final List<RecurringRule> _rules = [];

  List<Txn> get items => List.unmodifiable(_items);
  List<RecurringRule> get rules => List.unmodifiable(_rules);

  Future<SharedPreferences> _freshPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  // ---------- Reading stored data safely ----------

  /// Prefix of the keys that keep the original text of stored data that
  /// could not be fully read, so a damaged record is never silently lost.
  static const corruptPrefix = 'unreadable_';

  /// At most this many damaged copies are kept; the oldest go first.
  static const _maxCorruptCopies = 3;

  int _skipped = 0;

  /// Number of stored records that could not be read since the last call,
  /// then resets it. The UI uses this to tell the user once.
  int takeSkipped() {
    final n = _skipped;
    _skipped = 0;
    return n;
  }

  /// Decodes a stored JSON list, keeping every entry that is valid and
  /// counting the ones that are not. A completely unreadable value counts
  /// as one skipped entry.
  static ({List<T> ok, int skipped}) _decodeList<T>(
      String? raw, T Function(Map<String, dynamic>) parse) {
    if (raw == null) return (ok: <T>[], skipped: 0);
    Object? data;
    try {
      data = jsonDecode(raw);
    } on FormatException {
      return (ok: <T>[], skipped: 1);
    }
    if (data is! List) return (ok: <T>[], skipped: 1);
    final ok = <T>[];
    var skipped = 0;
    for (final e in data) {
      try {
        ok.add(parse(e as Map<String, dynamic>));
      } catch (_) {
        skipped++;
      }
    }
    return (ok: ok, skipped: skipped);
  }

  /// Saves the original text of a damaged value under its own key.
  Future<void> _keepCorrupt(
      SharedPreferences prefs, String key, String raw) async {
    var stamp = DateTime.now().microsecondsSinceEpoch;
    while (prefs.containsKey('$corruptPrefix${key}_$stamp')) {
      stamp++;
    }
    await prefs.setString('$corruptPrefix${key}_$stamp', raw);
    final copies = _corruptKeys(prefs);
    final extra = copies.length - _maxCorruptCopies;
    for (final k in copies.take(extra < 0 ? 0 : extra)) {
      await prefs.remove(k);
    }
  }

  /// Keys of the kept damaged copies, oldest first.
  static List<String> _corruptKeys(SharedPreferences prefs) {
    int stampOf(String key) =>
        int.tryParse(key.substring(key.lastIndexOf('_') + 1)) ?? 0;
    return prefs.getKeys().where((k) => k.startsWith(corruptPrefix)).toList()
      ..sort((a, b) => stampOf(a).compareTo(stampOf(b)));
  }

  /// Loads everything from [prefs]. Damaged entries are skipped and their
  /// original text is kept aside. Returns true if anything was skipped, in
  /// which case the caller must write the cleaned data back.
  Future<bool> _readFrom(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    final rawRules = prefs.getString(_rulesKey);
    final tx = _decodeList(raw, Txn.fromJson);
    final rules = _decodeList(rawRules, RecurringRule.fromJson);
    _items
      ..clear()
      ..addAll(tx.ok);
    _rules
      ..clear()
      ..addAll(rules.ok);
    if (tx.skipped > 0) await _keepCorrupt(prefs, _key, raw!);
    if (rules.skipped > 0) await _keepCorrupt(prefs, _rulesKey, rawRules!);
    _skipped += tx.skipped + rules.skipped;
    _unreadable = [
      for (final k in _corruptKeys(prefs)) prefs.getString(k) ?? '',
    ];
    return tx.skipped + rules.skipped > 0;
  }

  /// Original text of damaged data kept on the device, oldest first. It is
  /// included in backups so it can still be recovered by hand.
  List<String> _unreadable = const [];

  Future<void> _write(SharedPreferences prefs) async {
    await prefs.setString(
        _key, jsonEncode(_items.map((e) => e.toJson()).toList()));
    await prefs.setString(
        _rulesKey, jsonEncode(_rules.map((e) => e.toJson()).toList()));
  }

  /// Books every fixed rule whose day has arrived. Returns true if anything
  /// was added.
  bool _materialize() {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    var changed = false;
    for (var r = 0; r < _rules.length; r++) {
      var rule = _rules[r];
      final startYm = ymOf(rule.createdAt);
      for (var ym = startYm; ym <= ymOf(today); ym++) {
        if (!rule.isPending(ym)) continue;
        final date = rule.occurrenceIn(ym);
        if (date.isAfter(today)) break;
        _items.add(Txn(
          id: 'r${rule.id}_$ym',
          type: rule.type,
          amount: rule.amount,
          category: rule.category,
          note: rule.note,
          date: date,
          recurringId: rule.id,
        ));
        rule = rule.copyWith(lastYm: ym);
        changed = true;
      }
      _rules[r] = rule;
    }
    return changed;
  }

  Future<void> load() async {
    final prefs = await _freshPrefs();
    final repaired = await _readFrom(prefs);
    final booked = _materialize();
    notifyListeners();
    // Damaged entries are already kept aside, so the cleaned data can be
    // written back; otherwise each launch would store another copy.
    if (booked || repaired) await _write(prefs);
  }

  Future<void> _mutate(void Function() change) async {
    final prefs = await _freshPrefs();
    await _readFrom(prefs);
    change();
    _materialize();
    notifyListeners();
    await _write(prefs);
  }

  void _put(Txn t) {
    final i = _items.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      _items[i] = t;
    } else {
      _items.add(t);
    }
  }

  Future<void> upsert(Txn t) => _mutate(() => _put(t));

  Future<void> remove(String id) =>
      _mutate(() => _items.removeWhere((e) => e.id == id));

  /// Adds or edits a fixed rule. Editing keeps the booking history, so the
  /// change only affects months that are still to come.
  Future<void> upsertRule(RecurringRule rule) => _mutate(() {
        final i = _rules.indexWhere((e) => e.id == rule.id);
        if (i >= 0) {
          _rules[i] = RecurringRule(
            id: rule.id,
            type: rule.type,
            amount: rule.amount,
            category: rule.category,
            note: rule.note,
            day: rule.day,
            createdAt: _rules[i].createdAt,
            lastYm: _rules[i].lastYm,
          );
        } else {
          _rules.add(rule);
        }
      });

  /// Deletes a rule. Records already booked from it are kept.
  Future<void> removeRule(String id) =>
      _mutate(() => _rules.removeWhere((e) => e.id == id));

  /// Transactions with start <= date < end, newest first.
  List<Txn> inRange(DateTime start, DateTime end) {
    final r = _items
        .where((t) => !t.date.isBefore(start) && t.date.isBefore(end))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return r;
  }

  /// Balance of everything recorded up to now (future-dated records and
  /// fixed rules whose day hasn't come are not counted).
  double currentBalance() {
    final now = _clock();
    return _items
        .where((t) => !t.date.isAfter(now))
        .fold(0.0, (s, t) => s + (t.isIncome ? t.amount : -t.amount));
  }

  /// Fixed-rule occurrences in [start, end) that are not booked yet.
  List<PlannedItem> plannedBetween(DateTime start, DateTime end) {
    final out = <PlannedItem>[];
    final lastDay = end.subtract(const Duration(days: 1));
    for (final rule in _rules) {
      for (var ym = ymOf(start); ym <= ymOf(lastDay); ym++) {
        final d = rule.occurrenceIn(ym);
        if (d.isBefore(start) || !d.isBefore(end)) continue;
        if (rule.isPending(ym)) out.add(PlannedItem(rule, d));
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'transactions': _items.map((e) => e.toJson()).toList(),
        'recurring': _rules.map((e) => e.toJson()).toList(),
        if (_unreadable.isNotEmpty) 'unreadable': _unreadable,
      });

  /// Merges a JSON backup (same id overwrites). Accepts both the current
  /// format and older backups that were a plain list of transactions.
  /// Returns the number of imported records. Throws on invalid input.
  Future<int> importJson(String raw) async {
    final data = jsonDecode(raw);
    final txList = data is List ? data : (data as Map)['transactions'] as List;
    final ruleList = data is Map ? (data['recurring'] as List? ?? []) : [];
    final txns =
        txList.map((e) => Txn.fromJson(e as Map<String, dynamic>)).toList();
    final rules = ruleList
        .map((e) => RecurringRule.fromJson(e as Map<String, dynamic>))
        .toList();
    await _mutate(() {
      txns.forEach(_put);
      for (final r in rules) {
        _rules.removeWhere((e) => e.id == r.id);
        _rules.add(r);
      }
    });
    return txns.length + rules.length;
  }
}
