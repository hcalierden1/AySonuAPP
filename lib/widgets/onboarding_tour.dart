import 'package:flutter/material.dart';

import '../theme.dart';

/// One stop of the first-launch tour. A null [target] shows a centered card
/// (used for the welcome and closing messages).
class TourStep {
  final GlobalKey? target;
  final IconData icon;
  final String title;
  final String text;
  const TourStep({
    this.target,
    required this.icon,
    required this.title,
    required this.text,
  });
}

/// Shows a coach-mark tour: the screen is dimmed, the target widget is
/// highlighted and an explanation card appears next to it.
Future<void> showTour(BuildContext context, List<TourStep> steps) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) => _TourOverlay(steps: steps),
    transitionsBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  ));
}

class _TourOverlay extends StatefulWidget {
  final List<TourStep> steps;
  const _TourOverlay({required this.steps});

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay> {
  int _i = 0;

  bool get _isLast => _i == widget.steps.length - 1;

  bool _moving = false;

  void _next() {
    if (_isLast) {
      Navigator.pop(context);
    } else {
      _goTo(_i + 1);
    }
  }

  void _back() {
    if (_i > 0) _goTo(_i - 1);
  }

  /// Scrolls the next target into view first, so its box never ends up
  /// below the bottom of the screen.
  Future<void> _goTo(int i) async {
    if (_moving) return;
    _moving = true;
    final ctx = widget.steps[i].target?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(ctx,
          alignment: 0.35,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic);
    }
    _moving = false;
    if (mounted) setState(() => _i = i);
  }

  /// The highlighted area, kept inside the visible screen.
  Rect? _targetRect(TourStep s, Size size, EdgeInsets pad) {
    final box = s.target?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    final r = (box.localToGlobal(Offset.zero) & box.size).inflate(6);
    const m = 4.0;
    final visible = Rect.fromLTRB(
        m, pad.top + m, size.width - m, size.height - pad.bottom - m);
    if (!r.overlaps(visible)) return null;
    return r.intersect(visible);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final step = widget.steps[_i];
    final target = _targetRect(step, size, pad);
    final hole = target ??
        Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0);

    final cardWidth = (size.width - 32).clamp(0.0, 400.0);
    final left = (size.width - cardWidth) / 2;

    Widget card = _TourCard(
      step: step,
      index: _i,
      count: widget.steps.length,
      isLast: _isLast,
      onNext: _next,
      onBack: _i > 0 ? _back : null,
      onSkip: () => Navigator.pop(context),
    );

    const edge = 12.0;
    final usable = size.height - pad.top - pad.bottom - edge * 2;
    Widget fit(double maxHeight) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(child: card),
        );

    Widget placed;
    if (target == null) {
      placed = Center(child: SizedBox(width: cardWidth, child: fit(usable)));
    } else {
      // Put the card on whichever side of the target has more room. If
      // neither side is big enough, pin it to the bottom of the screen.
      const gap = 12.0, minRoom = 210.0;
      final spaceBelow = size.height - pad.bottom - edge - target.bottom - gap;
      final spaceAbove = target.top - pad.top - edge - gap;
      final below = spaceBelow >= spaceAbove;
      final room = below ? spaceBelow : spaceAbove;
      final double? top, bottom;
      final double maxHeight;
      if (room >= minRoom) {
        top = below ? target.bottom + gap : null;
        bottom = below ? null : size.height - target.top + gap;
        maxHeight = room;
      } else {
        top = null;
        bottom = pad.bottom + edge;
        maxHeight = usable * 0.6;
      }
      placed = Stack(children: [
        Positioned(
          left: left,
          width: cardWidth,
          top: top,
          bottom: bottom,
          child: fit(maxHeight),
        ),
      ]);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context);
      },
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _next,
          child: Stack(
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<Rect?>(
                  tween: RectTween(end: hole),
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  builder: (_, r, _) => CustomPaint(
                    painter: _HolePainter(
                      hole: r ?? hole,
                      scrim: Colors.black.withValues(alpha: 0.72),
                      ring: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(key: ValueKey(_i), child: placed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HolePainter extends CustomPainter {
  final Rect hole;
  final Color scrim;
  final Color ring;
  _HolePainter({required this.hole, required this.scrim, required this.ring});

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(hole, const Radius.circular(28));
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rr);
    canvas.drawPath(path, Paint()..color = scrim);
    if (hole.width > 1) {
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = ring,
      );
    }
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.hole != hole;
}

class _TourCard extends StatelessWidget {
  final TourStep step;
  final int index, count;
  final bool isLast;
  final VoidCallback onNext, onSkip;
  final VoidCallback? onBack;

  const _TourCard({
    required this.step,
    required this.index,
    required this.count,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {}, // taps on the card itself don't advance the tour
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 14),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(kRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: AppColors.gradient),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(step.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(step.title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                Text('${index + 1}/$count',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),
            Text(step.text,
                style: TextStyle(
                    fontSize: 14.5, height: 1.4, color: scheme.onSurface)),
            const SizedBox(height: 14),
            Row(
              children: [
                // progress dots (shrink on very narrow screens)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        children: [
                          for (var d = 0; d < count; d++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.only(right: 4),
                              width: d == index ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: d == index
                                    ? scheme.primary
                                    : scheme.primary.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  TextButton(
                    onPressed: onSkip,
                    child: const Text('Atla'),
                  )
                else if (onBack != null)
                  TextButton(onPressed: onBack, child: const Text('Geri')),
                const SizedBox(width: 4),
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                  onPressed: onNext,
                  child: Text(isLast
                      ? 'Başlayalım'
                      : index == 0
                          ? 'Turu başlat'
                          : 'İleri'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
