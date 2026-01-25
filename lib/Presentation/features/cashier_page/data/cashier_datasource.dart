import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';

class CashierDataSource {
  final _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> drinksStream() =>
      _firestore.collection('drinks').orderBy('posOrder').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> blendsStream() =>
      _firestore.collection('blends').orderBy('posOrder').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> singlesStream() =>
      _firestore.collection('singles').orderBy('posOrder').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> extrasStream({String? category}) {
    Query<Map<String, dynamic>> q = _firestore.collection('extras');
    if (category != null) {
      q = q.where('category', isEqualTo: category);
    }
    return q.orderBy('posOrder').snapshots();
  }

  Future<void> registerSale(String productId, int quantity) async {
    final docRef = _firestore.collection('products').doc(productId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception(AppStrings.errorProductNotFound);
      }

      final currentStock = snapshot['stock'] as int;
      if (currentStock < quantity) {
        throw Exception(AppStrings.errorQtyUnavailable);
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
