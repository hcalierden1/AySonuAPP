import 'dart:ui' show Color, DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/transaction_store.dart';
import '../models/transaction.dart';
import '../utils/period.dart';
import '../utils/quick_parse.dart';

/// Optional persistent notification that lets the user add income/expense
/// straight from the notification shade, without opening the app.
class QuickEntry {
  static const _notifId = 7001;
  static const _channelId = 'quick_entry';
  static const _prefKey = 'quick_entry_enabled';
  static const actionIncome = 'add_income';
  static const actionExpense = 'add_expense';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _settings = InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_wallet'),
  );

  /// Call once from the UI isolate.
  static Future<void> init() async {
    if (!supported || _initialized) return;
    await _plugin.initialize(
      settings: _settings,
      onDidReceiveBackgroundNotificationResponse: quickEntryBackgroundHandler,
    );
    _initialized = true;
  }

  static Future<bool> isEnabled() async {
    if (!supported) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Turns the feature on/off. Returns the resulting state (false if the
  /// user refused the notification permission).
  static Future<bool> setEnabled(bool enabled, TransactionStore store) async {
    if (!supported) return false;
    await init();
    final prefs = await SharedPreferences.getInstance();
    if (enabled) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? true;
      if (!granted) return false;
      await prefs.setBool(_prefKey, true);
      await _show(store);
      return true;
    }
    await prefs.setBool(_prefKey, false);
    await _plugin.cancel(id: _notifId);
    return false;
  }

  /// Re-posts the notification with fresh totals if the feature is on.
  static Future<void> refresh(TransactionStore store) async {
    if (await isEnabled()) {
      await init();
      await _show(store);
    }
  }

  static Future<void> _show(TransactionStore store, {String? status}) async {
    final today = Period.containing(PeriodKind.daily, DateTime.now());
    final txns = store.inRange(today.start, today.end);
    final income =
        txns.where((t) => t.isIncome).fold<double>(0, (s, t) => s + t.amount);
    final expense =
        txns.where((t) => !t.isIncome).fold<double>(0, (s, t) => s + t.amount);

    final title =
        'Bugün  +${money.format(income)}   −${money.format(expense)}';
    final body = status ??
        'Gelir veya gider eklemek için aşağıdaki butona dokunun. '
            'Örnek: 250 market';

    const inputHint = 'Tutar ve not · ör. 250 market';
    final details = AndroidNotificationDetails(
      _channelId,
      'Hızlı kayıt',
      channelDescription:
          'Bildirim panelinden gelir ve gider eklemek için kalıcı bildirim',
      icon: 'ic_stat_wallet',
      color: const Color(0xFF6A5AE8),
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      styleInformation: BigTextStyleInformation(body),
      actions: const [
        AndroidNotificationAction(
          actionExpense,
          'Gider ekle',
          cancelNotification: false,
          inputs: [AndroidNotificationActionInput(label: inputHint)],
        ),
        AndroidNotificationAction(
          actionIncome,
          'Gelir ekle',
          cancelNotification: false,
          inputs: [AndroidNotificationActionInput(label: inputHint)],
        ),
      ],
    );
    await _plugin.show(
      id: _notifId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
    );
  }

  /// Handles a reply typed into the notification.
  static Future<void> handle(NotificationResponse r) async {
    final action = r.actionId;
    if (action != actionIncome && action != actionExpense) return;
    final type = action == actionIncome ? TxType.income : TxType.expense;
    final input = r.input ?? '';

    final store = TransactionStore();
    await store.load();
    final txn = parseQuickEntry(input, type);
    String status;
    if (txn == null) {
      status = '⚠️ Tutar anlaşılamadı: "$input". Örnek: 250 market';
    } else {
      await store.upsert(txn);
      final sign = txn.isIncome ? '+' : '−';
      final note = txn.note.isEmpty ? '' : ' (${txn.note})';
      status = '✓ Kaydedildi: ${txn.category}$note  $sign${money.format(txn.amount)}';
    }
    await init();
    await _show(store, status: status);
  }
}

/// Runs in a background isolate when a notification action is used while
/// the app is closed or in the background.
@pragma('vm:entry-point')
Future<void> quickEntryBackgroundHandler(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  await QuickEntry.handle(r);
}
