import 'package:cloud_firestore/cloud_firestore.dart';

class SaleItem {
  final String productId, name, type, unit;
  final double quantity, sellTotal, costTotal;
  final Map<String, dynamic>? variant;
  SaleItem({
    required this.productId,
    required this.name,
    required this.type,
    required this.unit,
    required this.quantity,
    required this.sellTotal,
    required this.costTotal,
    this.variant,
  });

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'name': name,
    'type': type,
    'unit': unit,
    'quantity': quantity,
    'sellTotal': sellTotal,
    'costTotal': costTotal,
    'variant': variant,
  };
}

class SalesService {
  final _db = FirebaseFirestore.instance;

  // احسب الخصومات هنا (نفس منطق الديالوج لكن سريع للـ Transaction والتدقيق)
  Future<Map<String, double>> _computeDeductions(List<SaleItem> items) async {
    final result = <String, double>{};
    for (final it in items) {
      final q = await _db
          .collection('recipes')
          .where('productId', isEqualTo: it.productId)
          .get();
      final all = q.docs.map((d) => d.data()).toList();

      final filtered = all.where((r) {
        final v = (r['variant'] as Map<String, dynamic>?) ?? {};
        if (v.isEmpty) return true;
        if (it.variant == null) return false;
        for (final k in v.keys) {
          if ('${it.variant![k]}' != '${v[k]}') return false;
        }
        return true;
      });

      for (final r in filtered) {
        final ds = (r['deductions'] as List? ?? []);
        for (final d in ds) {
          final sid = d['stockItemId'] as String;
          final grams = ((d['gramsPerUnit'] ?? 0).toDouble()) * it.quantity;
          result.update(sid, (v) => v + grams, ifAbsent: () => grams);
        }
      }
    }
    return result;
  }

  Future<void> commitSale({
    required String cashierId,
    required List<SaleItem> items,
  }) async {
    if (items.isEmpty) return;

    final saleRef = _db.collection('sales').doc();

    // إجماليات
    final sellTotal = items.fold<double>(0, (p, e) => p + e.sellTotal);
    final costTotal = items.fold<double>(0, (p, e) => p + e.costTotal);
    final profitTotal = sellTotal - costTotal;

    // احسب الخصومات
    final deductions = await _computeDeductions(items);

    await _db.runTransaction((tx) async {
      // 1) اكتب البيع
      tx.set(saleRef, {
        'createdAt': DateTime.now().toUtc(),
        'createdBy': cashierId,
        'items': items.map((e) => e.toMap()).toList(),
        'sellTotal': sellTotal,
        'costTotal': costTotal,
        'profitTotal': profitTotal,
      });

      // 2) خصم المخزون
      for (final entry in deductions.entries) {
        final stockRef = _db.collection('stock_items').doc(entry.key);
        final snap = await tx.get(stockRef);
        if (!snap.exists) {
          throw Exception('Stock item غير موجود: ${entry.key}');
        }
        final data = snap.data() as Map<String, dynamic>;
        final current = (data['quantityGrams'] ?? 0).toDouble();
        final next = current - entry.value;
        if (next < 0) {
          throw Exception(
            'كمية غير كافية في المخزون لـ ${data['name']} (مطلوب ${entry.value}g، متاح $current g)',
          );
        }
        tx.update(stockRef, {'quantityGrams': next});
      }
    });
  }
}
