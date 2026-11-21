import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/transaction_store.dart';
import '../models/categories.dart';
import '../models/transaction.dart';
import '../theme.dart';
import '../utils/period.dart';

class TransactionFormScreen extends StatefulWidget {
  final TransactionStore store;
  final Txn? existing;
  final TxType? initialType;

  /// The day selected in the daily view; new records are saved on this day.
  final DateTime? day;

  const TransactionFormScreen({
    super.key,
    required this.store,
    this.existing,
    this.initialType,
    this.day,
  });

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TxType _type;
  late String _category;
  late DateTime _date;
  late final TextEditingController _amount;
  late final TextEditingController _note;

  bool get _isEdit => widget.existing != null;
  Color get _color =>
      _type == TxType.income ? AppColors.income : AppColors.expense;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType ?? TxType.expense;
    _category = e?.category ?? categoriesFor(_type).first.name;
    _date = e?.date ?? _defaultDate();
    _amount = TextEditingController(
        text: e == null
            ? ''
            : NumberFormat('#,##0.##', 'tr_TR').format(e.amount));
    _note = TextEditingController(text: e?.note ?? '');
  }

  DateTime _defaultDate() {
    final now = DateTime.now();
    final d = widget.day;
    if (d == null || dateOnly(d) == dateOnly(now)) return now;
    return DateTime(d.year, d.month, d.day, 12);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setType(TxType t) {
    setState(() {
      _type = t;
      if (!categoriesFor(t).any((c) => c.name == _category)) {
        _category = categoriesFor(t).first.name;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day,
          _date.hour, _date.minute));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.store.upsert(Txn(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type,
      amount: parseAmount(_amount.text)!,
      category: _category,
      note: _note.text.trim(),
      date: _date,
      recurringId: widget.existing?.recurringId,
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.delete_rounded, color: AppColors.expense),
        title: const Text('Kaydı sil'),
        content: const Text('Bu kayıt kalıcı olarak silinsin mi?'),
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
      await widget.store.remove(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

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
        title: Text(_isEdit ? 'Kaydı düzenle' : 'Yeni kayıt'),
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

            // Amount
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: dark ? 0.16 : 0.1),
                borderRadius: BorderRadius.circular(kRadius),
              ),
              child: Column(
                children: [
                  Text('Tutar (₺)',
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
                      hintStyle: TextStyle(color: _color.withValues(alpha: 0.35)),
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
            const FormLabel('Tarih'),
            const SizedBox(height: 10),
            SoftCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: _pickDate,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.calendar_month_rounded,
                        color: scheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(DateFormat('d MMMM y, EEEE').format(_date),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: scheme.outline),
                ],
              ),
            ),

            const SizedBox(height: 22),
            const FormLabel('Not'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _note,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'İsteğe bağlı açıklama',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),

            const SizedBox(height: 28),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: _color.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(58),
                ),
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(_isEdit ? 'Değişiklikleri kaydet' : 'Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FormLabel extends StatelessWidget {
  final String text;
  const FormLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      );
}

/// Two big rounded buttons: Gider / Gelir, with a sliding colored thumb.
class TypeSwitch extends StatelessWidget {
  final TxType value;
  final ValueChanged<TxType> onChanged;
  const TypeSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = value == TxType.income;
    final color = isIncome ? AppColors.income : AppColors.expense;

    Widget option(TxType t, String label, IconData icon) {
      final sel = t == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(t),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20,
                  color: sel
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: sel
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: isIncome ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                option(TxType.expense, 'Gider', Icons.north_east_rounded),
                option(TxType.income, 'Gelir', Icons.south_west_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryTile extends StatelessWidget {
  final Category category;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const CategoryTile({
    super.key,
    required this.category,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: dark ? 0.25 : 0.14)
              : (dark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.8,
          ),
        ),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? color : color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(category.icon,
                  size: 20, color: selected ? Colors.white : color),
            ),
            const SizedBox(height: 6),
            Text(category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? color : scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}
