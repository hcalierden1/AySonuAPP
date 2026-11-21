import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_gider/data/transaction_store.dart';
import 'package:gelir_gider/main.dart';
import 'package:gelir_gider/models/recurring.dart';
import 'package:gelir_gider/models/transaction.dart';
import 'package:gelir_gider/utils/period.dart';
import 'package:gelir_gider/utils/quick_parse.dart';
import 'package:gelir_gider/widgets/donut_chart.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'tr_TR';
    await initializeDateFormatting('tr_TR');
  });

  group('Period', () {
    test('weekly starts on Monday and spans 7 days', () {
      final p = Period.containing(PeriodKind.weekly, DateTime(2026, 11, 20));
      expect(p.start, DateTime(2026, 11, 16));
      expect(p.end, DateTime(2026, 11, 23));
    });

    test('monthly covers whole month', () {
      final p = Period.containing(PeriodKind.monthly, DateTime(2026, 2, 14));
      expect(p.start, DateTime(2026, 2, 1));
      expect(p.end, DateTime(2026, 3, 1));
      expect(p.dayCount, 28);
      expect(p.shift(-2).start, DateTime(2025, 12, 1));
    });
  });

  test('donut center text per tab', () {
    final day = DateTime(2026, 11, 20);
    var c = periodCenterText(Period.containing(PeriodKind.daily, day));
    expect((c.main, c.sub), ('20 Kasım', 'Cuma'));
    c = periodCenterText(Period.containing(PeriodKind.weekly, day));
    expect((c.main, c.sub), ('16–22', 'Kasım'));
    c = periodCenterText(
        Period.containing(PeriodKind.weekly, DateTime(2026, 12, 2)));
    expect(c.main, '30 Kas – 6 Ara');
    c = periodCenterText(Period.containing(PeriodKind.monthly, day));
    expect((c.main, c.sub), ('Kasım', '2026'));
  });

  test('parseAmount handles Turkish and plain formats', () {
    expect(parseAmount('1.250,50'), 1250.5);
    expect(parseAmount('1250.5'), 1250.5);
    expect(parseAmount('12'), 12);
    expect(parseAmount('abc'), isNull);
  });

  group('parseQuickEntry', () {
    final now = DateTime(2026, 11, 20, 9);
    Txn? p(String s, [TxType t = TxType.expense]) =>
        parseQuickEntry(s, t, now: now);

    test('amount + category', () {
      final t = p('250 market')!;
      expect(t.amount, 250);
      expect(t.category, 'Market');
      expect(t.note, '');
      expect(t.date, now);
    });
    test('Turkish formats, accents and extra note', () {
      final t = p('1.250,50 ULASIM otobüs kartı')!;
      expect(t.amount, 1250.5);
      expect(t.category, 'Ulaşım');
      expect(t.note, 'otobüs kartı');
    });
    test('category before amount, income, multi-word category', () {
      expect(p('maaş 42000', TxType.income)!.category, 'Maaş');
      final ek = p('ek gelir 3500 freelance', TxType.income)!;
      expect(ek.category, 'Ek Gelir');
      expect(ek.note, 'freelance');
    });
    test('unknown word becomes note in Diğer', () {
      final t = p('80 kuaför')!;
      expect(t.category, 'Diğer');
      expect(t.note, 'kuaför');
    });
    test('invalid input', () {
      expect(p('market'), isNull);
      expect(p(''), isNull);
      expect(p('0'), isNull);
    });
  });

  group('fixed monthly records', () {
    late DateTime now;
    Future<TransactionStore> open() async {
      final s = TransactionStore(clock: () => now);
      await s.load();
      return s;
    }

    RecurringRule rule(String id, TxType t, double a, int day, DateTime at) =>
        RecurringRule(
            id: id,
            type: t,
            amount: a,
            category: t == TxType.income ? 'Maaş' : 'Kira',
            day: day,
            createdAt: at);

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('salary on the 5th is booked only when the 5th arrives', () async {
      now = DateTime(2026, 11, 20, 10);
      var s = await open();
      await s.upsertRule(rule('maas', TxType.income, 35000, 5, now));
      expect(s.currentBalance(), 0, reason: 'nothing before the day');
      final dec = Period.containing(PeriodKind.monthly, DateTime(2026, 12));
      final planned = s.plannedBetween(dec.start, dec.end);
      expect(planned.single.date, DateTime(2026, 12, 5));

      now = DateTime(2026, 12, 4, 23, 59);
      s = await open();
      expect(s.currentBalance(), 0);

      now = DateTime(2026, 12, 5, 0, 1);
      s = await open();
      expect(s.currentBalance(), 35000);
      expect(s.items.single.recurringId, 'maas');
      expect(s.plannedBetween(dec.start, dec.end), isEmpty);

      s = await open(); // reopening doesn't book twice
      expect(s.items.length, 1);

      now = DateTime(2027, 1, 10);
      s = await open();
      expect(s.currentBalance(), 70000);
    });

    test('rent on the 15th: 20k stays 20k until the 15th, then 5k', () async {
      now = DateTime(2026, 11, 10);
      var s = await open();
      await s.upsert(Txn(
          id: 'start',
          type: TxType.income,
          amount: 20000,
          category: 'Diğer',
          date: DateTime(2026, 11, 1)));
      await s.upsertRule(rule('kira', TxType.expense, 15000, 15, now));
      expect(s.currentBalance(), 20000);

      now = DateTime(2026, 11, 14, 22);
      s = await open();
      expect(s.currentBalance(), 20000);

      now = DateTime(2026, 11, 15, 8);
      s = await open();
      expect(s.currentBalance(), 5000);
    });

    test('created on the same day books immediately', () async {
      now = DateTime(2026, 11, 15, 12);
      final s = await open();
      await s.upsertRule(rule('kira', TxType.expense, 15000, 15, now));
      expect(s.currentBalance(), -15000);
    });

    test('day 31 falls on the last day of short months', () async {
      now = DateTime(2027, 1, 31);
      var s = await open();
      await s.upsertRule(rule('x', TxType.expense, 100, 31, now));
      now = DateTime(2027, 3, 1);
      s = await open();
      expect(s.items.map((t) => t.date).toSet(),
          {DateTime(2027, 1, 31), DateTime(2027, 2, 28)});
    });

    test('a booked record deleted by the user is not re-created', () async {
      now = DateTime(2026, 11, 5);
      var s = await open();
      await s.upsertRule(rule('maas', TxType.income, 35000, 5, now));
      await s.remove(s.items.single.id);
      s = await open();
      expect(s.items, isEmpty);
    });

    test('deleting a rule keeps past records, stops future ones', () async {
      now = DateTime(2026, 11, 5);
      var s = await open();
      await s.upsertRule(rule('maas', TxType.income, 35000, 5, now));
      await s.removeRule('maas');
      now = DateTime(2027, 2, 1);
      s = await open();
      expect(s.items.length, 1);
    });

    test('backup round-trip keeps rules', () async {
      now = DateTime(2026, 11, 20);
      final s = await open();
      await s.upsertRule(rule('maas', TxType.income, 35000, 5, now));
      final backup = s.exportJson();
      SharedPreferences.setMockInitialValues({});
      final other = await open();
      await other.importJson(backup);
      expect(other.rules.single.id, 'maas');
    });
  });

  test('store sees records written by another instance', () async {
    SharedPreferences.setMockInitialValues({});
    final app = TransactionStore();
    await app.load();
    final background = TransactionStore();
    await background.load();
    await background.upsert(Txn(
        id: 'bg',
        type: TxType.expense,
        amount: 50,
        category: 'Yemek',
        date: DateTime(2026, 11, 20)));
    // The app adds its own record without reloading first: nothing is lost.
    await app.upsert(Txn(
        id: 'fg',
        type: TxType.income,
        amount: 10,
        category: 'Diğer',
        date: DateTime(2026, 11, 20)));
    expect(app.items.map((t) => t.id).toSet(), {'bg', 'fg'});
  });

  test('store persists and filters by range', () async {
    SharedPreferences.setMockInitialValues({});
    final s = TransactionStore();
    await s.load();
    await s.upsert(Txn(
        id: '1',
        type: TxType.expense,
        amount: 100,
        category: 'Market',
        date: DateTime(2026, 11, 20, 10)));
    await s.upsert(Txn(
        id: '2',
        type: TxType.income,
        amount: 5000,
        category: 'Maaş',
        date: DateTime(2026, 10, 1)));

    final reloaded = TransactionStore();
    await reloaded.load();
    expect(reloaded.items.length, 2);
    final nov = Period.containing(PeriodKind.monthly, DateTime(2026, 11, 1));
    expect(reloaded.inRange(nov.start, nov.end).map((t) => t.id), ['1']);

    final backup = reloaded.exportJson();
    final other = TransactionStore();
    expect(await other.importJson(backup), 2);
  });

  testWidgets('tour shows on first launch only', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    Future<void> launch() async {
      final store = TransactionStore();
      await store.load();
      await tester.pumpWidget(GelirGiderApp(key: UniqueKey(), store: store));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    await launch();
    expect(find.text('Hoş geldiniz! 👋'), findsOneWidget);
    await tester.tap(find.text('Turu başlat'));
    await tester.pumpAndSettle();
    expect(find.text('Kayıt ekleyin'), findsOneWidget);
    // Walk through every step to the end.
    // Walk through every step (guarded so a stuck step fails, not hangs).
    for (var guard = 0;
        guard < 12 && find.text('İleri').evaluate().isNotEmpty;
        guard++) {
      await tester.ensureVisible(find.text('İleri'));
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Hazırsınız! 🎉'), findsOneWidget);
    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();
    expect(find.text('Hazırsınız! 🎉'), findsNothing);

    // Second launch: no tour.
    await launch();
    expect(find.text('Hoş geldiniz! 👋'), findsNothing);
    expect(find.text('Gider Ekle'), findsOneWidget);
  });

  testWidgets('add an expense from home screen', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done_v1': true});
    final store = TransactionStore();
    await store.load();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GelirGiderApp(store: store));
    await tester.pumpAndSettle();

    // Daily view is the default and the only one with add buttons.
    expect(find.text('Bu güne ait kayıt yok'), findsOneWidget);
    await tester.tap(find.text('Gider Ekle'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '250,75');
    await tester.dragUntilVisible(find.text('Kaydet'),
        find.byType(ListView).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(store.items.single.amount, 250.75);
    expect(store.items.single.type, TxType.expense);
    expect(find.text('Bu güne ait kayıt yok'), findsNothing);
    expect(find.text('Market'), findsWidgets);

    // Weekly and monthly views are read-only summaries.
    for (final tab in ['Haftalık', 'Aylık']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.text('Gider Ekle'), findsNothing);
      expect(find.text('Gelir Ekle'), findsNothing);
      expect(find.textContaining('otomatik hesaplanır'), findsOneWidget);
    }
  });
}
