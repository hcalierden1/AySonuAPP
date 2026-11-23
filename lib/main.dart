import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'data/transaction_store.dart';
import 'screens/home_screen.dart';
import 'services/quick_entry.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'tr_TR';
  await initializeDateFormatting('tr_TR');
  final store = TransactionStore();
  await store.load();
  // A notification problem must never keep the app from opening.
  try {
    await QuickEntry.init();
  } catch (e) {
    debugPrint('Quick entry notification unavailable: $e');
  }
  // Keep the notification totals in sync with changes made in the app.
  store.addListener(() => QuickEntry.refresh(store));
  QuickEntry.refresh(store);
  runApp(GelirGiderApp(store: store));
}

class GelirGiderApp extends StatelessWidget {
  final TransactionStore store;
  const GelirGiderApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ay Sonu',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // On tablets keep the phone-like layout centered instead of stretched.
      // Very large system font sizes would push the layout off screen, so
      // the text scale is capped (it still grows up to 15%).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
        ),
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: child,
            ),
          ),
        ),
      ),
      home: HomeScreen(store: store),
    );
  }
}
