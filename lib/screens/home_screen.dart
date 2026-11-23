import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/transaction_store.dart';
import '../models/categories.dart';
import '../models/recurring.dart';
import '../models/transaction.dart';
import '../services/quick_entry.dart';
import '../theme.dart';
import '../utils/period.dart';
import '../widgets/donut_chart.dart';
import '../widgets/onboarding_tour.dart';
import 'recurring_screen.dart';
import 'transaction_form_screen.dart';

const _weekdayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

class HomeScreen extends StatefulWidget {
  final TransactionStore store;
  const HomeScreen({super.key, required this.store});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Period _period = Period.containing(PeriodKind.daily, DateTime.now());

  TransactionStore get store => widget.store;

  bool _quickEnabled = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    QuickEntry.isEnabled().then((v) {
      if (mounted) setState(() => _quickEnabled = v);
    });
    // Pick up records added from the notification while we were away.
    _lifecycle = AppLifecycleListener(onResume: store.load);
    store.addListener(_reportSkipped);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportSkipped(); // the first load happened before this screen existed
      _startTour();
    });
  }

  /// Tells the user once if some stored records were damaged and skipped.
  void _reportSkipped() {
    final n = store.takeSkipped();
    if (n == 0 || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      content: Text('$n kayıt okunamadı ve atlandı. Diğer kayıtlarınız '
          'güvende; bozuk verinin aslı cihazda saklandı ve yedeğe eklenir.'),
    ));
  }

  // ---------- First-launch tour ----------

  static const _tourDoneKey = 'onboarding_done_v1';
  bool _touring = false;
  final _kAdd = GlobalKey();
  final _kWeek = GlobalKey();
  final _kNav = GlobalKey();
  final _kBalance = GlobalKey();
  final _kTabs = GlobalKey();
  final _kMenu = GlobalKey();
  final _kFixed = GlobalKey();

  /// Keys are attached only while the tour runs, so the animated page
  /// transitions never see the same GlobalKey twice.
  Widget _tourTarget(GlobalKey key, Widget child) =>
      KeyedSubtree(key: _touring ? key : null, child: child);

  Future<void> _startTour({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool(_tourDoneKey) ?? false)) return;
    if (!mounted) return;
    setState(() {
      _touring = true;
      _period = Period.containing(PeriodKind.daily, DateTime.now());
    });
    // Let the daily page finish building / animating in.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await showTour(context, [
      const TourStep(
        icon: Icons.waving_hand_rounded,
        title: 'Hoş geldiniz! 👋',
        text: 'Ay Sonu ile günlük, haftalık ve aylık gelir-giderlerinizi '
            'kolayca takip edebilirsiniz. Kısa bir turla nerede ne '
            'yapıldığını gösterelim.',
      ),
      TourStep(
        target: _kAdd,
        icon: Icons.add_rounded,
        title: 'Kayıt ekleyin',
        text: 'Para girdiğinde "Gelir Ekle"ye, harcama yaptığınızda '
            '"Gider Ekle"ye dokunun. Tutarı yazın, kategoriyi seçin ve '
            'kaydedin.',
      ),
      TourStep(
        target: _kFixed,
        icon: Icons.event_repeat_rounded,
        title: 'Sabit gelir / giderler',
        text: 'Maaş, kira gibi her ay aynı gün tekrar edenleri buradan bir '
            'kez girin. Günü gelince otomatik eklenir; o güne kadar '
            'bakiyenizi etkilemez.',
      ),
      TourStep(
        target: _kWeek,
        icon: Icons.calendar_view_week_rounded,
        title: 'Gün seçin',
        text: 'Haftanın günlerine dokunarak o güne geçin. Altında nokta '
            'olan günlerde kayıt vardır.',
      ),
      TourStep(
        target: _kNav,
        icon: Icons.swap_horiz_rounded,
        title: 'Tarihler arasında gezinin',
        text: 'Oklarla önceki ve sonraki güne geçin. Tarihe dokunursanız '
            'takvim açılır. Ekranı sağa-sola kaydırmak da işe yarar.',
      ),
      TourStep(
        target: _kBalance,
        icon: Icons.account_balance_wallet_rounded,
        title: 'Günün özeti',
        text: 'Seçili günün toplam geliri, gideri ve elinizde kalan '
            'bakiye burada görünür.',
      ),
      TourStep(
        target: _kTabs,
        icon: Icons.insights_rounded,
        title: 'Haftalık ve aylık özet',
        text: 'Haftalık (Pazartesi–Pazar) ve Aylık (ayın 1\'i – ay sonu) '
            'sayfaları günlük kayıtlarınızdan otomatik hesaplanır. Bu '
            'sayfalarda kayıt girilmez, sadece özet gösterilir.',
      ),
      TourStep(
        target: _kMenu,
        icon: Icons.more_horiz_rounded,
        title: 'Menü',
        text: QuickEntry.supported
            ? 'Bildirim panelinden hızlı kaydı açabilir, yedek alabilir ve '
                'bu turu tekrar izleyebilirsiniz.'
            : 'Yedek alabilir ve bu turu tekrar izleyebilirsiniz.',
      ),
      const TourStep(
        icon: Icons.celebration_rounded,
        title: 'Hazırsınız! 🎉',
        text: 'İpucu: Bir kayda dokunarak düzenleyebilir, sola kaydırarak '
            'silebilirsiniz.',
      ),
    ]);
    await prefs.setBool(_tourDoneKey, true);
    if (mounted) setState(() => _touring = false);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    store.removeListener(_reportSkipped);
    super.dispose();
  }

  Future<void> _toggleQuickEntry() async {
    final want = !_quickEnabled;
    final result = await QuickEntry.setEnabled(want, store);
    if (!mounted) return;
    setState(() => _quickEnabled = result);
    final msg = !want
        ? 'Bildirimden hızlı kayıt kapatıldı'
        : result
            ? 'Hazır! Ekranı yukarıdan aşağı kaydırıp "Gider ekle" veya '
                '"Gelir ekle"ye dokunun.'
            : 'Bildirim izni verilmedi. Ayarlar > Uygulamalar > Ay Sonu '
                '> Bildirimler bölümünden izin verebilirsiniz.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 5),
    ));
  }

  void _go(Period p) => setState(() => _period = p);

  void _setKind(PeriodKind k) {
    if (k == _period.kind) return;
    final now = DateTime.now();
    final anchor = _period.contains(now) ? now : _period.start;
    _go(Period.containing(k, anchor));
  }

  void _openDay(DateTime day) => _go(Period.containing(PeriodKind.daily, day));

  Future<void> _jumpToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _period.start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Tarihe git',
    );
    if (picked != null) _go(Period.containing(_period.kind, picked));
  }

  void _openForm({Txn? existing, TxType? type}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => TransactionFormScreen(
          store: store,
          existing: existing,
          initialType: type,
          day: _period.start,
        ),
        transitionsBuilder: (_, anim, _, child) {
          final curved =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                  .animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _deleteWithUndo(Txn t) {
    store.remove(t.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Kayıt silindi'),
        action: SnackBarAction(
            label: 'GERİ AL', onPressed: () => store.upsert(t)),
      ));
  }

  Future<void> _export() async {
    await Clipboard.setData(ClipboardData(text: store.exportJson()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '${store.items.length} kayıt panoya kopyalandı. Güvenli bir yere yapıştırın.'),
    ));
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final clipText = clip?.text?.trimLeft() ?? '';
    if (clipText.startsWith('[') || clipText.startsWith('{')) {
      controller.text = clip!.text!;
    }
    if (!mounted) return;
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yedeği içe aktar'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration:
              const InputDecoration(hintText: 'Yedek metnini buraya yapıştırın'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(c, controller.text),
              child: const Text('İçe aktar')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await store.importJson(text);
      messenger.showSnackBar(SnackBar(content: Text('$n kayıt içe aktarıldı')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Geçersiz yedek verisi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final txns = store.inRange(_period.start, _period.end);
            return Column(
              children: [
                _Header(
                  showToday: !_period.contains(DateTime.now()),
                  onToday: () =>
                      _go(Period.containing(_period.kind, DateTime.now())),
                  onExport: _export,
                  onImport: _import,
                  quickEnabled: _quickEnabled,
                  onToggleQuick:
                      QuickEntry.supported ? _toggleQuickEntry : null,
                  onTour: () => _startTour(force: true),
                  onRecurring: _openRecurring,
                  menuKey: _touring ? _kMenu : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _tourTarget(
                    _kTabs,
                    _PeriodTabs(value: _period.kind, onChanged: _setKind),
                  ),
                ),
                _tourTarget(
                  _kNav,
                  _PeriodNavigator(
                    label: _period.label,
                    onPrev: () => _go(_period.shift(-1)),
                    onNext: () => _go(_period.shift(1)),
                    onTapLabel: _jumpToDate,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v.abs() < 300) return;
                      _go(_period.shift(v > 0 ? -1 : 1));
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: ListView(
                        key: ValueKey('${_period.kind}${_period.start}'),
                        // During the tour keep off-screen targets alive so
                        // the tour can scroll back to them.
                        cacheExtent: _touring ? 3000 : null,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        children: _period.kind == PeriodKind.daily
                            ? _dailyContent(txns)
                            : _summaryContent(txns),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------- Daily: the only place where records are entered ----------

  List<Widget> _dailyContent(List<Txn> txns) {
    final weekStart =
        Period.containing(PeriodKind.weekly, _period.start).start;
    final weekTxns =
        store.inRange(weekStart, DateTime(weekStart.year, weekStart.month, weekStart.day + 7));
    return [
      _tourTarget(
        _kWeek,
        _WeekStrip(
          weekStart: weekStart,
          selected: _period.start,
          daysWithData: weekTxns.map((t) => dateOnly(t.date)).toSet(),
          onSelect: _openDay,
        ),
      ),
      const SizedBox(height: 14),
      _tourTarget(
        _kBalance,
        _BalanceCard(
          title: 'Günün özeti',
          txns: txns,
          margin: EdgeInsets.zero,
          currentBalance: store.currentBalance(),
        ),
      ),
      const SizedBox(height: 14),
      _tourTarget(_kAdd, Row(
        children: [
          Expanded(
            child: _AddButton(
              label: 'Gelir Ekle',
              icon: Icons.south_west_rounded,
              color: AppColors.income,
              onTap: () => _openForm(type: TxType.income),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _AddButton(
              label: 'Gider Ekle',
              icon: Icons.north_east_rounded,
              color: AppColors.expense,
              onTap: () => _openForm(type: TxType.expense),
            ),
          ),
        ],
      )),
      const SizedBox(height: 10),
      _tourTarget(
        _kFixed,
        _FixedButton(
          ruleCount: store.rules.length,
          onTap: () => _openRecurring(),
        ),
      ),
      _SectionTitle(
          'Kayıtlar', txns.isEmpty ? null : '${txns.length} işlem'),
      if (txns.isEmpty)
        const _EmptyState(
          icon: Icons.edit_note_rounded,
          title: 'Bu güne ait kayıt yok',
          subtitle: 'Yukarıdaki butonlarla gelir veya gider ekleyin',
        )
      else
        for (final t in txns)
          Dismissible(
            key: ValueKey(t.id),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(top: 10),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.delete_rounded, color: AppColors.expense),
            ),
            onDismissed: (_) => _deleteWithUndo(t),
            child: _TxnTile(txn: t, onTap: () => _openForm(existing: t)),
          ),
      ..._donuts(txns),
      ..._plannedSection(),
    ];
  }

  /// Income and expense donuts by category for the current period.
  List<Widget> _donuts(List<Txn> txns) => [
        const _SectionTitle('Kategorilere göre'),
        CategoryDonutCard(type: TxType.income, txns: txns, period: _period),
        CategoryDonutCard(type: TxType.expense, txns: txns, period: _period),
      ];

  /// Fixed records of this period whose day hasn't come yet.
  List<Widget> _plannedSection() {
    final planned = store.plannedBetween(_period.start, _period.end);
    if (planned.isEmpty) return const [];
    return [
      const _SectionTitle('Planlanan sabit kayıtlar', 'Günü gelince eklenir'),
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Text(
          'Bunlar henüz bakiyenize yansımadı. Günü geldiğinde otomatik '
          'eklenecek.',
          style: TextStyle(fontSize: 12.5),
        ),
      ),
      for (final p in planned)
        _PlannedTile(item: p, onTap: () => _openRecurring(p.rule)),
    ];
  }

  void _openRecurring([RecurringRule? rule]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => rule == null
            ? RecurringScreen(store: store)
            : RecurringFormScreen(store: store, existing: rule),
      ),
    );
  }

  // ---------- Weekly / Monthly: automatic, read-only summaries ----------

  List<Widget> _summaryContent(List<Txn> txns) {
    final weekly = _period.kind == PeriodKind.weekly;
    return [
      _BalanceCard(
        title: weekly ? 'Haftanın özeti' : 'Ayın özeti',
        txns: txns,
        currentBalance: store.currentBalance(),
      ),
      const _AutoInfo(),
      _DailyChart(period: _period, txns: txns, onDayTap: _openDay),
      ..._donuts(txns),
      if (weekly)
        ..._weekDays(txns)
      else
        ..._monthWeeks(txns),
      ..._plannedSection(),
      if (!weekly && store.rules.isEmpty)
        SoftCard(
          margin: const EdgeInsets.only(top: 24),
          onTap: () => _openRecurring(),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.gradient),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.event_repeat_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sabit gelir / gider ekleyin',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Maaş, kira gibi her ay tekrar edenleri bir kez '
                        'girin; günü gelince otomatik eklensin.',
                        style: TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
    ];
  }

  List<Widget> _weekDays(List<Txn> txns) {
    return [
      const _SectionTitle('Günler', 'Pazartesi – Pazar'),
      for (var i = 0; i < 7; i++)
        Builder(builder: (_) {
          final day = DateTime(
              _period.start.year, _period.start.month, _period.start.day + i);
          final dayTxns = txns.where((t) => dateOnly(t.date) == day).toList();
          return _SummaryRow(
            badge: _weekdayShort[i],
            title: DateFormat('EEEE').format(day),
            subtitle: DateFormat('d MMMM').format(day),
            txns: dayTxns,
            highlight: day == dateOnly(DateTime.now()),
            onTap: () => _openDay(day),
          );
        }),
    ];
  }

  List<Widget> _monthWeeks(List<Txn> txns) {
    final rows = <Widget>[
      const _SectionTitle('Haftalar', 'Ay başından ay sonuna'),
    ];
    var weekStart = Period.containing(PeriodKind.weekly, _period.start).start;
    var n = 1;
    while (weekStart.isBefore(_period.end)) {
      final weekEnd =
          DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
      final from = weekStart.isBefore(_period.start) ? _period.start : weekStart;
      final to = weekEnd.isAfter(_period.end) ? _period.end : weekEnd;
      final lastDay = DateTime(to.year, to.month, to.day - 1);
      final weekTxns = txns
          .where((t) => !t.date.isBefore(from) && t.date.isBefore(to))
          .toList();
      final ws = weekStart;
      rows.add(_SummaryRow(
        badge: '$n.',
        title: '$n. hafta',
        subtitle: from.day == lastDay.day
            ? DateFormat('d MMMM').format(from)
            : '${from.day} – ${DateFormat('d MMMM').format(lastDay)}',
        txns: weekTxns,
        highlight: !DateTime.now().isBefore(from) && DateTime.now().isBefore(to),
        onTap: () => _go(Period.containing(PeriodKind.weekly, ws)),
      ));
      weekStart = weekEnd;
      n++;
    }
    return rows;
  }
}

// ======================================================================
// Widgets
// ======================================================================

class _Header extends StatelessWidget {
  final VoidCallback onToday, onExport, onImport;
  final bool showToday;
  final bool quickEnabled;
  final VoidCallback? onToggleQuick;
  final VoidCallback onTour;
  final VoidCallback onRecurring;
  final GlobalKey? menuKey;
  const _Header({
    required this.onToday,
    required this.onExport,
    required this.onImport,
    required this.showToday,
    required this.quickEnabled,
    this.onToggleQuick,
    required this.onTour,
    required this.onRecurring,
    this.menuKey,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.gradient),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ay Sonu',
                    style: text.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text(DateFormat('d MMMM, EEEE').format(DateTime.now()),
                    style: text.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: showToday
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: onToday,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.undo_rounded,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 6),
                              Text('Bugün',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          PopupMenuButton<String>(
            key: menuKey,
            tooltip: 'Menü',
            onSelected: (v) => switch (v) {
              'export' => onExport(),
              'import' => onImport(),
              'tour' => onTour(),
              'recurring' => onRecurring(),
              _ => onToggleQuick?.call(),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'recurring',
                  child: ListTile(
                      leading: Icon(Icons.event_repeat_rounded),
                      title: Text('Sabit gelir / giderler'),
                      subtitle: Text('Maaş, kira, fatura...'))),
              const PopupMenuDivider(),
              if (onToggleQuick != null) ...[
                PopupMenuItem(
                  value: 'quick',
                  child: ListTile(
                    leading: const Icon(Icons.notifications_active_rounded),
                    title: const Text('Bildirimden hızlı kayıt'),
                    subtitle: Text(quickEnabled ? 'Açık' : 'Kapalı'),
                    trailing: IgnorePointer(
                      child: Switch(value: quickEnabled, onChanged: (_) {}),
                    ),
                  ),
                ),
                const PopupMenuDivider(),
              ],
              const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                      leading: Icon(Icons.upload_rounded),
                      title: Text('Yedeği dışa aktar'))),
              const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                      leading: Icon(Icons.download_rounded),
                      title: Text('Yedeği içe aktar'))),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'tour',
                  child: ListTile(
                      leading: Icon(Icons.help_outline_rounded),
                      title: Text('Uygulama turunu göster'))),
            ],
            child: IgnorePointer(
              child: SoftIconButton(
                  icon: Icons.more_horiz_rounded, onPressed: () {}),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped tab switcher with a sliding gradient thumb.
class _PeriodTabs extends StatelessWidget {
  final PeriodKind value;
  final ValueChanged<PeriodKind> onChanged;
  const _PeriodTabs({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const kinds = PeriodKind.values;
    final index = kinds.indexOf(value);
    return Container(
      height: 52,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / kinds.length;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              left: w * index,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.gradient),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (final k in kinds)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(k),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge!
                              .copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: k == value
                                ? Colors.white
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                          child: Text(k.label),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _PeriodNavigator extends StatelessWidget {
  final String label;
  final VoidCallback onPrev, onNext, onTapLabel;
  const _PeriodNavigator({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onTapLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          SoftIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Önceki',
              onPressed: onPrev),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTapLabel,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label,
                            maxLines: 1,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          SoftIconButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Sonraki',
              onPressed: onNext),
        ],
      ),
    );
  }
}

/// Monday–Sunday day buttons shown in the daily view.
class _WeekStrip extends StatelessWidget {
  final DateTime weekStart;
  final DateTime selected;
  final Set<DateTime> daysWithData;
  final ValueChanged<DateTime> onSelect;

  const _WeekStrip({
    required this.weekStart,
    required this.selected,
    required this.daysWithData,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final today = dateOnly(DateTime.now());
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Builder(builder: (_) {
            final day =
                DateTime(weekStart.year, weekStart.month, weekStart.day + i);
            final isSel = day == selected;
            final isToday = day == today;
            final fg = isSel ? Colors.white : scheme.onSurface;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => onSelect(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSel
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: AppColors.gradient)
                          : null,
                      color: isSel
                          ? null
                          : (dark ? AppColors.darkCard : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: isToday && !isSel
                          ? Border.all(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              width: 1.5)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(_weekdayShort[i],
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: fg.withValues(alpha: 0.75))),
                        const SizedBox(height: 4),
                        Text('${day.day}',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: fg)),
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: daysWithData.contains(day)
                                ? (isSel ? Colors.white : AppColors.primary)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Gradient balance card with income / expense pills.
class _BalanceCard extends StatelessWidget {
  final String title;
  final List<Txn> txns;
  final EdgeInsetsGeometry margin;
  final double? currentBalance;
  const _BalanceCard({
    required this.title,
    required this.txns,
    this.margin = const EdgeInsets.only(top: 14),
    this.currentBalance,
  });

  @override
  Widget build(BuildContext context) {
    final income =
        txns.where((t) => t.isIncome).fold<double>(0, (s, t) => s + t.amount);
    final expense =
        txns.where((t) => !t.isIncome).fold<double>(0, (s, t) => s + t.amount);
    final net = income - expense;

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.gradient,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(money.format(net),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                      child: _BalancePill(
                          label: 'Gelir',
                          value: income,
                          icon: Icons.south_west_rounded)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _BalancePill(
                          label: 'Gider',
                          value: expense,
                          icon: Icons.north_east_rounded)),
                ],
              ),
              if (currentBalance != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('Mevcut bakiye',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(money.format(currentBalance),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A fixed monthly record whose day hasn't come yet. Shown faded, with a
/// note that it doesn't affect the balance until then.
class _PlannedTile extends StatelessWidget {
  final PlannedItem item;
  final VoidCallback onTap;
  const _PlannedTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rule = item.rule;
    final color = rule.isIncome ? AppColors.income : AppColors.expense;
    final days = item.date.difference(dateOnly(DateTime.now())).inDays;
    final when = days == 0
        ? 'bugün'
        : days == 1
            ? 'yarın'
            : '$days gün sonra';
    return Opacity(
      opacity: 0.75,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(
              color: scheme.outlineVariant, width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(iconFor(rule.type, rule.category),
                        color: color),
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
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 13, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${DateFormat('d MMMM').format(item.date)} · $when',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${rule.isIncome ? '+' : '−'}${money.format(rule.amount)}',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BalancePill extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  const _BalancePill(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85))),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(money.format(value),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Big soft "add" button with a tinted background.
class _AddButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AddButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: color.withValues(alpha: dark ? 0.2 : 0.13),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
              const SizedBox(width: 8),
              // Shrinks instead of cutting the label on narrow phones.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      maxLines: 1,
                      style: TextStyle(
                          color: dark
                              ? color
                              : Color.lerp(color, Colors.black, 0.25),
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry point for fixed monthly income / expenses (salary, rent...).
class _FixedButton extends StatelessWidget {
  final int ruleCount;
  final VoidCallback onTap;
  const _FixedButton({required this.ruleCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.event_repeat_rounded, size: 22, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sabit gelir / giderler',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: scheme.onSurface)),
                    Text(
                        ruleCount == 0
                            ? 'Maaş, kira gibi her ay tekrar edenleri ekleyin'
                            : '$ruleCount sabit kayıt · günü gelince otomatik eklenir',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoInfo extends StatelessWidget {
  const _AutoInfo();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bu özet günlük kayıtlarınızdan otomatik hesaplanır. '
              'Kayıt eklemek için bir güne dokunun.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionTitle(this.title, [this.trailing]);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 0),
      child: Row(
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          if (trailing != null)
            Expanded(
              child: Text(trailing!,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

/// One day (weekly view) or one week (monthly view) as a tappable row.
class _SummaryRow extends StatelessWidget {
  final String badge, title, subtitle;
  final List<Txn> txns;
  final bool highlight;
  final VoidCallback onTap;

  const _SummaryRow({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.txns,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final income =
        txns.where((t) => t.isIncome).fold<double>(0, (s, t) => s + t.amount);
    final expense =
        txns.where((t) => !t.isIncome).fold<double>(0, (s, t) => s + t.amount);
    final net = income - expense;

    return SoftCard(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: highlight
                  ? const LinearGradient(colors: AppColors.gradient)
                  : null,
              color: highlight ? null : scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(badge,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: highlight ? Colors.white : scheme.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (txns.isEmpty)
            Text('Kayıt yok',
                style: TextStyle(fontSize: 12, color: scheme.outline))
          else
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(money.format(net),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: net >= 0
                                ? AppColors.income
                                : AppColors.expense)),
                    const SizedBox(height: 2),
                    Text(
                      '+${money.format(income)}  −${money.format(expense)}',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: scheme.outline),
        ],
      ),
    );
  }
}

/// Daily income/expense bars for weekly and monthly views.
class _DailyChart extends StatelessWidget {
  final Period period;
  final List<Txn> txns;
  final ValueChanged<DateTime> onDayTap;
  const _DailyChart(
      {required this.period, required this.txns, required this.onDayTap});

  static const _h = 130.0;

  @override
  Widget build(BuildContext context) {
    final n = period.dayCount;
    final inc = List<double>.filled(n, 0);
    final exp = List<double>.filled(n, 0);
    for (final t in txns) {
      final d = dateOnly(t.date);
      final i = DateTime.utc(d.year, d.month, d.day)
          .difference(DateTime.utc(
              period.start.year, period.start.month, period.start.day))
          .inDays;
      if (i < 0 || i >= n) continue;
      if (t.isIncome) {
        inc[i] += t.amount;
      } else {
        exp[i] += t.amount;
      }
    }
    final maxV = [...inc, ...exp].fold<double>(0, math.max);
    final scheme = Theme.of(context).colorScheme;
    final weekly = period.kind == PeriodKind.weekly;

    String labelFor(int i) {
      if (weekly) return _weekdayShort[i];
      final day = i + 1;
      return (day == 1 || day % 5 == 0) ? '$day' : '';
    }

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Günlere göre',
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              const _Legend(color: AppColors.income, label: 'Gelir'),
              const SizedBox(width: 12),
              const _Legend(color: AppColors.expense, label: 'Gider'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: _h,
            child: Stack(
              children: [
                // soft guide lines
                for (final f in [0.0, 0.5, 1.0])
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _h * f,
                    child: Container(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onDayTap(DateTime(period.start.year,
                              period.start.month, period.start.day + i)),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: weekly ? 7 : 1),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _bar(inc[i], maxV, AppColors.income, weekly),
                                SizedBox(width: weekly ? 3 : 1),
                                _bar(exp[i], maxV, AppColors.expense, weekly),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: Text(labelFor(i),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                ),
            ],
          ),
          if (maxV == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text('Bu dönemde henüz kayıt yok',
                    style:
                        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(double v, double maxV, Color c, bool weekly) {
    final h = maxV == 0 ? 0.0 : (v / maxV) * _h;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        height: v > 0 ? math.max(h, 4) : 0,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [c.withValues(alpha: 0.55), c],
          ),
          borderRadius: BorderRadius.circular(weekly ? 8 : 3),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _TxnTile extends StatelessWidget {
  final Txn txn;
  final VoidCallback onTap;
  const _TxnTile({required this.txn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = txn.isIncome ? AppColors.income : AppColors.expense;
    return SoftCard(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(iconFor(txn.type, txn.category), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(txn.category,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    if (txn.recurringId != null) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Sabit kayıttan otomatik eklendi',
                        child: Icon(Icons.event_repeat_rounded,
                            size: 15, color: scheme.primary),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  txn.note.isEmpty
                      ? (txn.recurringId != null
                          ? 'Sabit ${txn.isIncome ? 'gelir' : 'gider'}'
                          : (txn.isIncome ? 'Gelir' : 'Gider'))
                      : txn.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${txn.isIncome ? '+' : '−'}${money.format(txn.amount)}',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: scheme.primary),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
