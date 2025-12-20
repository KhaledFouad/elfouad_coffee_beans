import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SalesPageResult {
  SalesPageResult({
    required this.docs,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

class SalesHistoryRepository {
  SalesHistoryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  static const int pageSize = 30;

  // صفحة واحدة (للـ List مع "عرض المزيد")
  Future<SalesPageResult> fetchPage({
    required DateTimeRange range,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final baseQuery = _firestore
        .collection('sales')
        .where(
          'created_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('created_at', isLessThan: Timestamp.fromDate(range.end))
        .orderBy('created_at', descending: true);

    var pagedQuery = baseQuery.limit(pageSize);
    if (startAfter != null) {
      pagedQuery = pagedQuery.startAfterDocument(startAfter);
    }

    final baseSnap = await pagedQuery.get();
    var docs = baseSnap.docs;

    // أول صفحة: ضيف معاها الفواتير المؤجلة الغير مسددة
    if (startAfter == null) {
      final settledFuture = _firestore
          .collection('sales')
          .where(
            'settled_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
          )
          .where('settled_at', isLessThan: Timestamp.fromDate(range.end))
          .where('paid', isEqualTo: true)
          .orderBy('settled_at', descending: true)
          .get();

      final deferredFuture = _firestore
          .collection('sales')
          .where('is_deferred', isEqualTo: true)
          .where('paid', isEqualTo: false)
          .get();

      final settledSnap = await settledFuture;
      final deferredSnap = await deferredFuture;

      if (deferredSnap.docs.isNotEmpty || settledSnap.docs.isNotEmpty) {
        final combined =
            <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final d in docs) {
          combined[d.id] = d;
        }
        for (final d in deferredSnap.docs) {
          combined[d.id] = d;
        }
        for (final d in settledSnap.docs) {
          combined[d.id] = d;
        }
        docs = combined.values.toList()
          ..sort((a, b) => _effectiveAtOf(b).compareTo(_effectiveAtOf(a)));
      }
    }

    final hasMore = baseSnap.docs.length == pageSize;
    final lastDoc = baseSnap.docs.isNotEmpty ? baseSnap.docs.last : startAfter;

    return SalesPageResult(docs: docs, lastDoc: lastDoc, hasMore: hasMore);
  }

  /// استعلام بدون Limit — بنستعمله علشان نحسب إجمالي اليوم كله للـ Summary
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllForRange({
    required DateTimeRange range,
  }) async {
    final createdFuture = _firestore
        .collection('sales')
        .where(
          'created_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('created_at', isLessThan: Timestamp.fromDate(range.end))
        .orderBy('created_at', descending: true)
        .get();

    final settledFuture = _firestore
        .collection('sales')
        .where(
          'settled_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('settled_at', isLessThan: Timestamp.fromDate(range.end))
        .where('paid', isEqualTo: true)
        .orderBy('settled_at', descending: true)
        .get();

    final createdSnap = await createdFuture;
    final settledSnap = await settledFuture;

    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in createdSnap.docs) {
      combined[d.id] = d;
    }
    for (final d in settledSnap.docs) {
      combined[d.id] = d;
    }

    return combined.values.toList();
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
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _settledAtOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final value = data['settled_at'];

    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _effectiveAtOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final paid = data['paid'] == true;
    if (paid && data['settled_at'] != null) {
      return _settledAtOf(doc);
    }
    return _createdAtOf(doc);
  }
}
