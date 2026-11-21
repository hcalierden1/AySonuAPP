import '../models/categories.dart';
import '../models/transaction.dart';
import 'period.dart';

/// Lower-cases Turkish text and strips accents so "Ulaşım", "ulasim" and
/// "ULAŞIM" all compare equal.
String normalizeTr(String s) {
  const map = {
    'İ': 'i', 'I': 'i', 'ı': 'i',
    'Ç': 'c', 'ç': 'c', 'Ğ': 'g', 'ğ': 'g', 'Ö': 'o', 'ö': 'o',
    'Ş': 's', 'ş': 's', 'Ü': 'u', 'ü': 'u',
  };
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(map[ch] ?? ch.toLowerCase());
  }
  return b.toString();
}

/// Turns free text typed in the notification, e.g. "250 market",
/// "1.250,50 öğle yemeği" or "maaş 42000", into a transaction.
/// Returns null if no positive amount is found.
Txn? parseQuickEntry(String input, TxType type, {DateTime? now}) {
  final text = input.trim();
  final m = RegExp(r'\d[\d.,]*').firstMatch(text);
  if (m == null) return null;
  final amount = parseAmount(m.group(0)!);
  if (amount == null || amount <= 0) return null;

  var rest = '${text.substring(0, m.start)} ${text.substring(m.end)}'
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('₺', '')
      .trim();

  var category = 'Diğer';
  final restNorm = normalizeTr(rest);
  // Longest names first so "Ek Gelir" wins over shorter matches.
  final cats = [...categoriesFor(type)]
    ..sort((a, b) => b.name.length.compareTo(a.name.length));
  for (final c in cats) {
    final cn = normalizeTr(c.name);
    final firstWord = restNorm.split(' ').first;
    if (restNorm == cn || restNorm.startsWith('$cn ')) {
      category = c.name;
      rest = rest.substring(c.name.length).trim();
      break;
    }
    if (firstWord.length >= 3 && cn.startsWith(firstWord)) {
      category = c.name;
      rest = rest.substring(firstWord.length).trim();
      break;
    }
  }

  final t = now ?? DateTime.now();
  return Txn(
    id: t.microsecondsSinceEpoch.toString(),
    type: type,
    amount: amount,
    category: category,
    note: rest,
    date: t,
  );
}
