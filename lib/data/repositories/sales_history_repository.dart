import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SalesHistoryRepository {
  SalesHistoryRepository(this._firestore);

  final FirebaseFirestore _firestore;
  static const int _historyLimit = 500;
  static const int _deferredLimit = 300;

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchSales({
    required DateTimeRange range,
  }) {
    final controller =
        StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.broadcast();

    var rangeDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var deferredDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var settledDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? rangeSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? deferredSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? settledSub;

    void emitCombined() {
      if (controller.isClosed) return;
      final merged = _mergeSnapshots(rangeDocs, deferredDocs, settledDocs);
      controller.add(merged);
    }

    controller.onListen = () {
      rangeSub = _rangeQuery(range).snapshots().listen(
        (snapshot) {
          rangeDocs = snapshot.docs;
          emitCombined();
        },
        onError: controller.addError,
      );

      deferredSub = _deferredQuery().snapshots().listen(
        (snapshot) {
          deferredDocs = snapshot.docs
              .where((doc) => (doc.data()['paid'] ?? false) != true)
              .toList();
          emitCombined();
        },
        onError: controller.addError,
      );

      settledSub = _settledQuery(range).snapshots().listen(
        (snapshot) {
          settledDocs = snapshot.docs;
          emitCombined();
        },
        onError: controller.addError,
      );
    };

    controller.onCancel = () async {
      await rangeSub?.cancel();
      await deferredSub?.cancel();
      await settledSub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  Future<void> settleDeferredSale(String saleId) async {
    final ref = _firestore.collection('sales').doc(saleId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw Exception('Sale not found');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final bool isDeferred = data['is_deferred'] == true;
      final double dueAmount = _parseDouble(data['due_amount']);

      if (!isDeferred || dueAmount <= 0) {
        throw Exception('Not a valid deferred sale.');
      }

      final double totalCost = _parseDouble(data['total_cost']);

      final components = (data['components'] as List?)
          ?.map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      if (components != null && components.isNotEmpty) {
        for (final component in components) {
          final grams = _parseDouble(component['grams']);
          final pricePerKg = _parseDouble(component['price_per_kg']);
          double pricePerGram = _parseDouble(component['price_per_g']);

          if (pricePerGram <= 0 && pricePerKg > 0) {
            pricePerGram = pricePerKg / 1000.0;
            component['price_per_g'] = pricePerGram;
            component['line_total_price'] = pricePerGram * grams;
          }
        }
        transaction.update(ref, {'components': components});
      }

      final newTotalPrice = dueAmount;
      final newProfit = newTotalPrice - totalCost;

      transaction.update(ref, {
        'total_price': newTotalPrice,
        'profit_total': newProfit,
        'is_deferred': false,
        'paid': true,
        'due_amount': 0.0,
        'settled_at': FieldValue.serverTimestamp(),
      });
    });
  }

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Query<Map<String, dynamic>> _rangeQuery(DateTimeRange range) {
    final start = range.start.toUtc();
    final end = range.end.toUtc();

    return _firestore
        .collection('sales')
        .where('created_at', isLessThan: end)
        .where('created_at', isGreaterThanOrEqualTo: start)
        .orderBy('created_at', descending: true)
        .limit(_historyLimit);
  }

  Query<Map<String, dynamic>> _deferredQuery() {
    return _firestore
        .collection('sales')
        .where('is_deferred', isEqualTo: true)
        .limit(_deferredLimit);
  }

  Query<Map<String, dynamic>> _settledQuery(DateTimeRange range) {
    final start = range.start.toUtc();
    final end = range.end.toUtc();

    return _firestore
        .collection('sales')
        .where('settled_at', isGreaterThanOrEqualTo: start)
        .where('settled_at', isLessThan: end)
        .orderBy('settled_at', descending: true)
        .limit(_historyLimit);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _mergeSnapshots(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> primary,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> deferred,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> settled,
  ) {
    if (primary.isEmpty && deferred.isEmpty && settled.isEmpty) {
      return const [];
    }

    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in primary) {
      combined[doc.id] = doc;
    }
    for (final doc in deferred) {
      combined[doc.id] = doc;
    }
    for (final doc in settled) {
      combined[doc.id] = doc;
    }

    final merged = combined.values.toList()
      ..sort(
        (a, b) => _createdAtOf(b).compareTo(_createdAtOf(a)),
      );
    return merged;
  }

  DateTime _createdAtOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final value = data['created_at'];

    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true).toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
