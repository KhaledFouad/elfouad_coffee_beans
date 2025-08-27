import 'package:cloud_firestore/cloud_firestore.dart';

class CashierDataSource {
  final _firestore = FirebaseFirestore.instance;

  Future<void> registerSale(String productId, int quantity) async {
    final docRef = _firestore.collection('products').doc(productId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception("المنتج مش موجود");
      }

      final currentStock = snapshot['stock'] as int;
      if (currentStock < quantity) {
        throw Exception("الكمية غير متاحة في المخزون");
      }

      // خصم الكمية
      transaction.update(docRef, {'stock': currentStock - quantity});

      // تسجيل البيع
      final saleRef = _firestore.collection('sales').doc();
      transaction.set(saleRef, {
        'productId': productId,
        'quantity': quantity,
        'date': DateTime.now().toIso8601String(),
      });
    });
  }
}
