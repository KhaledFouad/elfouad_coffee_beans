import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/data/models/extra_item.dart';

/// Stream of extras by category (active only), ordered by name.
/// ستريم للأصناف حسب التصنيف (الفعالة فقط) مرتبة بالاسم.
Stream<List<ExtraItem>> extrasStreamByCategory(String category) {
  final q = FirebaseFirestore.instance
      .collection('extras')
      .where('category', isEqualTo: category)
      .where('active', isEqualTo: true)
      .orderBy('name'); // قد يطلب Index أول مرة
  return q.snapshots().map(
    (s) => s.docs
        .map(
          (d) => ExtraItem.fromDoc(d as DocumentSnapshot<Map<String, dynamic>>),
        )
        .toList(),
  );
}

/// Sell N pieces from an extra item (transaction).
/// بيع عدد قطع من صنف (ترانزاكشن).
Future<void> sellExtra({
  required String extraId,
  required int qty,
  String? cashierId,
  String payment = 'cash',
}) async {
  final db = FirebaseFirestore.instance;
  final ref = db.collection('extras').doc(extraId);

  await db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    if (!snap.exists) throw 'الصنف غير موجود';
    final item = ExtraItem.fromDoc(snap);

    if (qty <= 0) throw 'كمية غير صالحة';
    if (item.stockUnits < qty) {
      throw 'المخزون غير كافٍ: المتاح ${item.stockUnits} قطعة';
    }

    final totalPrice = item.priceSell * qty;
    final totalCost = item.costUnit * qty;
    final profit = totalPrice - totalCost;

    // خصم المخزون
    tx.update(ref, {
      'stock_units': item.stockUnits - qty,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // إنشاء عملية بيع بنفس حقول السجل
    final saleRef = db.collection('sales').doc();
    tx.set(saleRef, {
      'type': 'extra',
      'source': 'extras',
      'extra_id': item.id,
      'name': item.name,
      'variant': item.variant,
      'unit': 'piece',
      'quantity': qty,
      'unit_price': item.priceSell,
      'total_price': totalPrice,
      'total_cost': totalCost,
      'profit_total': profit,
      'is_deferred': false,
      'paid': true,
      'payment_method': payment,
      'cashier_id': cashierId,
      'created_at': FieldValue.serverTimestamp(),
    });
  });
}
