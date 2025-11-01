import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedBiscuits() async {
  final db = FirebaseFirestore.instance;
  final items = <Map<String, dynamic>>[
    {
      'name': 'تمر دارك شوكلت',
      'category': 'biscuits',
      'variant': 'Dark',
      'price_sell': 5,
      'cost_unit': 3.8,
      'stock_units': 60,
    },
    {
      'name': 'تمر وايت شوكلت',
      'category': 'biscuits',
      'variant': 'White',
      'price_sell': 5,
      'cost_unit': 3.8,
      'stock_units': 60,
    },
    {
      'name': 'معمول سادة',
      'category': 'biscuits',
      'price_sell': 2.5,
      'cost_unit': 1.7,
      'stock_units': 500,
    },
    {
      'name': 'معمول تمر',
      'category': 'biscuits',
      'price_sell': 5,
      'cost_unit': 4.20,
      'stock_units': 20,
    },
    {
      'name': 'معمول قرفة',
      'category': 'biscuits',
      'price_sell': 5,
      'cost_unit': 4.20,
      'stock_units': 50,
    },
    {
      'name': 'معمول وايت شوكلت',
      'category': 'biscuits',
      'variant': 'White',
      'price_sell': 5,
      'cost_unit': 4.20,
      'stock_units': 50,
    },
    {
      'name': 'معمول دارك شوكلت',
      'category': 'biscuits',
      'variant': 'Dark',
      'price_sell': 5,
      'cost_unit': 4.20,
      'stock_units': 50,
    },
  ];
  for (final m in items) {
    final ref = db.collection('extras').doc();
    await ref.set({
      ...m,
      'unit': 'piece',
      'active': true,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
