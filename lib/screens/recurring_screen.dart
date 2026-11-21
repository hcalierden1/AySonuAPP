import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/transaction_store.dart';
import '../models/categories.dart';
import '../models/recurring.dart';
import '../models/transaction.dart';
import '../theme.dart';
import '../utils/period.dart';
import 'transaction_form_screen.dart';

/// Lists fixed monthly incomes/expenses (salary, rent, bills ...).
class RecurringScreen extends StatelessWidget {
  final TransactionStore store;
  const RecurringScreen({super.key, required this.store});

  void _open(BuildContext context, [RecurringRule? rule]) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => RecurringFormScreen(store: store, existing: rule)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: SoftIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Geri',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        leadingWidth: 64,
        title: const Text('Sabit gelir / giderler'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final now = DateTime.now();
          final rules = [...store.rules]
            ..sort((a, b) =>
                a.nextOccurrence(now).compareTo(b.nextOccurrence(now)));
          final income = rules
              .where((r) => r.isIncome)
              .fold<double>(0, (s, r) => s + r.amount);
          final expense = rules
              .where((r) => !r.isIncome)
              .fold<double>(0, (s, r) => s + r.amount);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 20, color: scheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Maaş, kira, fatura gibi her ay aynı gün tekrar eden '
                        'kayıtları buraya ekleyin. Kayıt, günü geldiğinde '
                        'otomatik eklenir; o güne kadar bakiyenizi etkilemez.',
                        style: TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              if (rules.isNotEmpty)
                SoftCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: _MonthlyTotal(
                            label: 'Aylık sabit gelir',
                            value: income,
                            color: AppColors.income),
                      ),
                      Container(
                          width: 1, height: 36, color: scheme.outlineVariant),
                      Expanded(
                        child: _MonthlyTotal(
                            label: 'Aylık sabit gider',
                            value: expense,
                            color: AppColors.expense),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              for (final r in rules)
                SoftCard(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  onTap: () => _open(context, r),
                  child: _RuleRow(rule: r, now: now),
                ),
              if (rules.isEmpty)
                SoftCard(
                  padding:
                      const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.event_repeat_rounded,
                            size: 36, color: scheme.primary),
                      ),
                      const SizedBox(height: 14),
                      const Text('Henüz sabit kayıt yok',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Örnek: Her ayın 5\'inde maaş, 15\'inde kira',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                onPressed: () => _open(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Sabit kayıt ekle'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthlyTotal extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MonthlyTotal(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(money.format(value),
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16, color: color)),
          ),
        ],
      );
}

class _RuleRow extends StatelessWidget {
  final RecurringRule rule;
  final DateTime now;
  const _RuleRow({required this.rule, required this.now});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = rule.isIncome ? AppColors.income : AppColors.expense;
    final next = rule.nextOccurrence(now);
    final days = next.difference(dateOnly(now)).inDays;
    final when = days == 0
        ? 'bugün'
        : days == 1
            ? 'yarın'
            : '$days gün sonra';
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(iconFor(rule.type, rule.category), color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rule.note.isEmpty ? rule.category : rule.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text('Her ayın ${rule.day}\'${_suffix(rule.day)}',
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant)),
              Text(
                  'Sonraki: ${DateFormat('d MMMM').format(next)} ($when)',
                  style: TextStyle(fontSize: 12, color: scheme.primary)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${rule.isIncome ? '+' : '−'}${money.format(rule.amount)}',
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ],
    );
  }
}

/// Turkish ordinal suffix used after an apostrophe: 5'i, 15'i, 20'si ...
String _suffix(int n) {
  const map = {
    1: 'i', 2: 'si', 3: 'ü', 4: 'ü', 5: 'i', 6: 'sı', 7: 'si', 8: 'i',
    9: 'u', 0: 'u',
  };
  if (n % 10 == 0) {
    return switch (n) { 10 => 'u', 20 => 'si', 30 => 'u', _ => 'u' };
  }
  return map[n % 10]!;
}

String dayLabel(int day) => "Her ayın $day'${_suffix(day)}";

// ======================================================================

class RecurringFormScreen extends StatefulWidget {
  final TransactionStore store;
  final RecurringRule? existing;
  const RecurringFormScreen({super.key, required this.store, this.existing});

  @override
  State<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends State<RecurringFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TxType _type;
  late String _category;
  late int _day;
  late final TextEditingController _amount;
  late final TextEditingController _note;

  bool get _isEdit => widget.existing != null;
  Color get _color =>
      _type == TxType.income ? AppColors.income : AppColors.expense;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? TxType.expense;
    _category = e?.category ?? categoriesFor(_type).first.name;
    _day = e?.day ?? DateTime.now().day;
    _amount = TextEditingController(
        text: e == null
            ? ''
            : NumberFormat('#,##0.##', 'tr_TR').format(e.amount));
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setType(TxType t) => setState(() {
        _type = t;
        if (!categoriesFor(t).any((c) => c.name == _category)) {
          _category = categoriesFor(t).first.name;
        }
      });

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final rule = RecurringRule(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type,
      amount: parseAmount(_amount.text)!,
      category: _category,
      note: _note.text.trim(),
      day: _day,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    await widget.store.upsertRule(rule);
    if (!mounted) return;
    final next = widget.store.rules
        .firstWhere((r) => r.id == rule.id)
        .nextOccurrence(DateTime.now());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Kaydedildi. İlk/sonraki kayıt ${DateFormat('d MMMM y').format(next)} '
          'tarihinde otomatik eklenecek.'),
    ));
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.delete_rounded, color: AppColors.expense),
        title: const Text('Sabit kaydı sil'),
        content: const Text(
            'Bundan sonra otomatik eklenmeyecek. Daha önce eklenmiş '
            'kayıtlar silinmez.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.expense,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.removeRule(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: SoftIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Kapat',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        leadingWidth: 64,
        title: Text(_isEdit ? 'Sabit kaydı düzenle' : 'Yeni sabit kayıt'),
        actions: [
          if (_isEdit)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SoftIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Sil',
                onPressed: _delete,
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TypeSwitch(value: _type, onChanged: _setType),
            const SizedBox(height: 18),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: dark ? 0.16 : 0.1),
                borderRadius: BorderRadius.circular(kRadius),
              ),
              child: Column(
                children: [
                  Text('Aylık tutar (₺)',
                      style: TextStyle(
                          color: _color, fontWeight: FontWeight.w700)),
                  TextFormField(
                    controller: _amount,
                    autofocus: !_isEdit,
                    textAlign: TextAlign.center,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: _color),
                    decoration: InputDecoration(
                      filled: false,
                      hintText: '0,00',
                      hintStyle:
                          TextStyle(color: _color.withValues(alpha: 0.35)),
                      errorStyle: const TextStyle(fontSize: 13),
                    ),
                    validator: (v) {
                      final a = parseAmount(v ?? '');
                      if (a == null) return 'Geçerli bir tutar girin';
                      if (a <= 0) return 'Tutar sıfırdan büyük olmalı';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const FormLabel('Ayın hangi günü?'),
                const Spacer(),
                Text(dayLabel(_day),
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: scheme.primary)),
              ],
            ),
            const SizedBox(height: 10),
            SoftCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(builder: (context, c) {
                const gap = 6.0;
                final w = (c.maxWidth - gap * 6) / 7;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var d = 1; d <= 31; d++)
                      GestureDetector(
                        onTap: () => setState(() => _day = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: w,
                          height: w.clamp(0, 44),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: d == _day
                                ? _color
                                : scheme.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text('$d',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: d == _day
                                      ? Colors.white
                                      : scheme.onSurface)),
                        ),
                      ),
                  ],
                );
              }),
            ),
            if (_day > 28)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                child: Text(
                  'Bu günü olmayan aylarda (ör. Şubat) ayın son gününe '
                  'eklenir.',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 22),
            const FormLabel('Kategori'),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, c) {
              const gap = 10.0;
              final w = (c.maxWidth - gap * 3) / 4;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final cat in categoriesFor(_type))
                    SizedBox(
                      width: w,
                      child: CategoryTile(
                        category: cat,
                        selected: _category == cat.name,
                        color: _color,
                        onTap: () => setState(() => _category = cat.name),
                      ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 22),
            const FormLabel('Açıklama'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'ör. Maaş, Ev kirası, İnternet faturası',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _color,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(58),
              ),
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_isEdit ? 'Değişiklikleri kaydet' : 'Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
