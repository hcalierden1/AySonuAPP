import 'package:flutter/material.dart';

import 'transaction.dart';

class Category {
  final String name;
  final IconData icon;
  const Category(this.name, this.icon);
}

const expenseCategories = <Category>[
  Category('Market', Icons.shopping_cart),
  Category('Yemek', Icons.restaurant),
  Category('Ulaşım', Icons.directions_bus),
  Category('Fatura', Icons.receipt_long),
  Category('Kira', Icons.home),
  Category('Sağlık', Icons.local_hospital),
  Category('Eğlence', Icons.movie),
  Category('Giyim', Icons.checkroom),
  Category('Eğitim', Icons.school),
  Category('Diğer', Icons.more_horiz),
];

const incomeCategories = <Category>[
  Category('Maaş', Icons.work),
  Category('Ek Gelir', Icons.add_business),
  Category('Yatırım', Icons.trending_up),
  Category('Hediye', Icons.card_giftcard),
  Category('Diğer', Icons.more_horiz),
];

List<Category> categoriesFor(TxType type) =>
    type == TxType.income ? incomeCategories : expenseCategories;

IconData iconFor(TxType type, String name) {
  for (final c in categoriesFor(type)) {
    if (c.name == name) return c.icon;
  }
  return Icons.label;
}
