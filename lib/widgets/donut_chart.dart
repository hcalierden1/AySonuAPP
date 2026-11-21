import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/categories.dart';
import '../models/transaction.dart';
import '../theme.dart';
import '../utils/period.dart';

/// One slice of a category donut.
class _Slice {
  final String label;
  final double value;
  final Color color;
  const _Slice(this.label, this.value, this.color);
}

/// Colour of a category. It always follows the category (Market is always
/// the same colour), never its rank. Categories beyond the 8 palette slots
/// and "Diğer" fold into a neutral "Diğer" slice.
Color? _slotColor(TxType type, String category, bool dark) {
  if (category == 'Diğer') return null;
  final names = categoriesFor(type).map((c) => c.name).toList();
  final i = names.indexOf(category);
  if (i < 0 || i >= 8) return null;
  return (dark ? AppColors.chartDark : AppColors.chartLight)[i];
}

/// Center text for the donut: date + weekday, week range or month name.
({String main, String sub}) periodCenterText(Period p) {
  switch (p.kind) {
    case PeriodKind.daily:
      return (
        main: DateFormat('d MMMM').format(p.start),
        sub: DateFormat('EEEE').format(p.start),
      );
    case PeriodKind.weekly:
      final last = DateTime(p.start.year, p.start.month, p.start.day + 6);
      if (p.start.month == last.month) {
        return (
          main: '${p.start.day}–${last.day}',
          sub: DateFormat('MMMM').format(last),
        );
      }
      return (
        main: '${DateFormat('d MMM').format(p.start)} – '
            '${DateFormat('d MMM').format(last)}',
        sub: '${last.year}',
      );
    case PeriodKind.monthly:
      return (
        main: DateFormat('MMMM').format(p.start),
        sub: '${p.start.year}',
      );
  }
}

/// Income or expense split by category, as a donut with a legend.
class CategoryDonutCard extends StatelessWidget {
  final TxType type;
  final List<Txn> txns;
  final Period period;

  const CategoryDonutCard({
    super.key,
    required this.type,
    required this.txns,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final isIncome = type == TxType.income;

    // Totals per category, keeping the fixed category order.
    final totals = <String, double>{};
    for (final t in txns.where((t) => t.type == type)) {
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    final slices = <_Slice>[];
    var other = 0.0;
    final otherNames = <String>[];
    for (final c in categoriesFor(type)) {
      final v = totals[c.name];
      if (v == null || v <= 0) continue;
      final color = _slotColor(type, c.name, dark);
      if (color == null) {
        other += v;
        otherNames.add(c.name);
      } else {
        slices.add(_Slice(c.name, v, color));
      }
    }
    if (other > 0) {
      slices.add(_Slice(otherNames.join(', '), other,
          dark ? AppColors.chartOtherDark : AppColors.chartOtherLight));
    }
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    // Biggest first in the legend; colours stay tied to the category.
    final legend = [...slices]..sort((a, b) => b.value.compareTo(a.value));
    final center = periodCenterText(period);
    final surface = dark ? AppColors.darkCard : Colors.white;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: (isIncome ? AppColors.income : AppColors.expense)
                      .withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    isIncome
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    size: 16,
                    color: isIncome ? AppColors.income : AppColors.expense),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(isIncome ? 'Gelirler' : 'Giderler',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Text(money.format(total),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            final donut = SizedBox(
                width: 132,
                height: 132,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('${period.kind}${period.start}$total'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, _) => CustomPaint(
                    painter: _DonutPainter(
                      slices: slices,
                      progress: t,
                      track: scheme.onSurface.withValues(alpha: 0.08),
                      gapColor: surface,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(26),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(center.main,
                                  maxLines: 1,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: scheme.onSurface)),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(center.sub,
                                  maxLines: 1,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            final info = legend.isEmpty
                ? Text(
                    isIncome
                        ? 'Bu dönemde gelir kaydı yok'
                        : 'Bu dönemde gider kaydı yok',
                    style:
                        TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final s in legend) _LegendRow(slice: s, total: total),
                    ],
                  );
            // Side by side when there is room; on narrow phones the legend
            // goes under the donut so amounts never wrap.
            if (box.maxWidth >= 270) {
              return Row(children: [
                donut,
                const SizedBox(width: 16),
                Expanded(child: info),
              ]);
            }
            return Column(children: [
              donut,
              const SizedBox(height: 12),
              legend.isEmpty ? Center(child: info) : info,
            ]);
          }),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final _Slice slice;
  final double total;
  const _LegendRow({required this.slice, required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (slice.value / total * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: slice.color, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slice.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(money.format(slice.value),
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(pct == 0 ? '<%1' : '%$pct',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface)),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_Slice> slices;
  final double progress;
  final Color track;
  final Color gapColor;

  _DonutPainter({
    required this.slices,
    required this.progress,
    required this.track,
    required this.gapColor,
  });

  static const _stroke = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2 - _stroke / 2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);

    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;

    final sweepTotal = math.pi * 2 * progress;
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.value / total * sweepTotal;
      canvas.drawArc(rect, start, sweep, false, base..color = s.color);
      start += sweep;
    }
    // 2px surface gaps between slices.
    if (slices.length > 1) {
      final gap = Paint()
        ..color = gapColor
        ..strokeWidth = 2.5;
      var a = -math.pi / 2;
      for (final s in slices) {
        final dir = Offset(math.cos(a), math.sin(a));
        final c = size.center(Offset.zero);
        canvas.drawLine(c + dir * (r - _stroke / 2 - 1),
            c + dir * (r + _stroke / 2 + 1), gap);
        a += s.value / total * sweepTotal;
      }
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.slices != slices ||
      old.gapColor != gapColor;
}
