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

  bool _isCreditHidden(Map<String, dynamic> data) =>
      data['credit_hidden'] == true;

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
      final bool isDeferred =
          data['is_deferred'] == true || data['is_credit'] == true;
      final double dueAmount = _resolveDueAmount(data);

      if (!isDeferred || dueAmount <= 0) {
        throw Exception('Not a valid deferred sale.');
      }

      final double totalCost = _parseDouble(data['total_cost']);
      final double totalPrice = _parseDouble(data['total_price']);

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

      final newProfit = totalPrice - totalCost;
      final now = Timestamp.now();
      final paymentEvents = _appendPaymentEvent(data, dueAmount, now);

      transaction.update(ref, {
        'profit_total': newProfit,
        'is_deferred': true,
        'paid': true,
        'due_amount': 0.0,
        'settled_at': FieldValue.serverTimestamp(),
        'last_payment_at': now,
        'last_payment_amount': dueAmount,
        'payment_events': paymentEvents,
      });
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchCreditSales() async {
    final deferredFuture = _firestore
        .collection('sales')
        .where('is_deferred', isEqualTo: true)
        .get();

    final creditFuture = _firestore
        .collection('sales')
        .where('is_credit', isEqualTo: true)
        .get();

    final settledFuture = _firestore
        .collection('sales')
        .where('settled_at', isNull: false)
        .get();

    final results = await Future.wait(
      [deferredFuture, creditFuture, settledFuture],
    );
    final deferredSnap = results[0];
    final creditSnap = results[1];
    final settledSnap = results[2];

    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in deferredSnap.docs) {
      combined[doc.id] = doc;
    }
    for (final doc in creditSnap.docs) {
      combined[doc.id] = doc;
    }
    for (final doc in settledSnap.docs) {
      combined[doc.id] = doc;
    }

    return combined.values
        .where((doc) => !_isCreditHidden(doc.data()))
        .toList();
  }

  Future<List<String>> fetchCreditCustomerNames() async {
    final docs = await fetchCreditSales();
    final lastPaidByName = <String, DateTime?>{};
    for (final doc in docs) {
      final data = doc.data();
      final name = (data['note'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        final latest = _latestPaymentAt(data);
        if (!lastPaidByName.containsKey(name)) {
          lastPaidByName[name] = latest;
          continue;
        }
        final existing = lastPaidByName[name];
        if (latest != null &&
            (existing == null || latest.isAfter(existing))) {
          lastPaidByName[name] = latest;
        }
      }
    }
    final sorted = lastPaidByName.keys.toList()
      ..sort((a, b) {
        final aAt = lastPaidByName[a];
        final bAt = lastPaidByName[b];
        if (aAt == null && bAt == null) return a.compareTo(b);
        if (aAt == null) return 1;
        if (bAt == null) return -1;
        final cmp = bAt.compareTo(aAt);
        if (cmp != 0) return cmp;
        return a.compareTo(b);
      });
    return sorted;
  }

  Future<int> fetchUnpaidCreditCount() async {
    final deferredFuture = _firestore
        .collection('sales')
        .where('is_deferred', isEqualTo: true)
        .where('paid', isEqualTo: false)
        .get();

    final creditFuture = _firestore
        .collection('sales')
        .where('is_credit', isEqualTo: true)
        .where('paid', isEqualTo: false)
        .get();

    final results = await Future.wait([deferredFuture, creditFuture]);
    final deferredSnap = results[0];
    final creditSnap = results[1];

    final combined =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in deferredSnap.docs) {
      combined[doc.id] = doc;
    }
    for (final doc in creditSnap.docs) {
      combined[doc.id] = doc;
    }

    return combined.values
        .where((doc) => !_isCreditHidden(doc.data()))
        .length;
  }

  Future<void> deleteCreditCustomer(String customerName) async {
    final name = customerName.trim();
    if (name.isEmpty) {
      throw Exception('Customer name is required.');
    }

    final deferredFuture = _firestore
        .collection('sales')
        .where('note', isEqualTo: name)
        .where('is_deferred', isEqualTo: true)
        .get();

    final creditFuture = _firestore
        .collection('sales')
        .where('note', isEqualTo: name)
        .where('is_credit', isEqualTo: true)
        .get();

    final results = await Future.wait([deferredFuture, creditFuture]);
    final deferredSnap = results[0];
    final creditSnap = results[1];

    final combined =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in deferredSnap.docs) {
      combined[doc.id] = doc;
    }
    for (final doc in creditSnap.docs) {
      combined[doc.id] = doc;
    }

    if (combined.isEmpty) {
      return;
    }

    const batchLimit = 400;
    var batch = _firestore.batch();
    var opCount = 0;
    for (final doc in combined.values) {
      batch.delete(doc.reference);
      opCount++;
      if (opCount >= batchLimit) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }
    if (opCount > 0) {
      await batch.commit();
    }
  }

  Future<void> applyCreditPayment({
    required String customerName,
    required double amount,
  }) async {
    final name = customerName.trim();
    if (name.isEmpty) {
      throw Exception('Customer name is required.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw Exception('Invalid payment amount.');
    }

    final deferredFuture = _firestore
        .collection('sales')
        .where('note', isEqualTo: name)
        .where('is_deferred', isEqualTo: true)
        .where('paid', isEqualTo: false)
        .get();

    final creditFuture = _firestore
        .collection('sales')
        .where('note', isEqualTo: name)
        .where('is_credit', isEqualTo: true)
        .where('paid', isEqualTo: false)
        .get();

    final results = await Future.wait([deferredFuture, creditFuture]);
    final deferredSnap = results[0];
    final creditSnap = results[1];

    final combined =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in deferredSnap.docs) {
      combined[doc.id] = doc;
    }
    for (final doc in creditSnap.docs) {
      combined[doc.id] = doc;
    }

    if (combined.isEmpty) {
      return;
    }

    final docs = combined.values.toList()
      ..sort((a, b) => _createdAtOf(a).compareTo(_createdAtOf(b)));

    await _firestore.runTransaction((transaction) async {
      final live = <DocumentReference<Map<String, dynamic>>,
          DocumentSnapshot<Map<String, dynamic>>>{};
      for (final doc in docs) {
        live[doc.reference] = await transaction.get(doc.reference);
      }

      var remaining = amount;
      final now = Timestamp.now();
      final updates = <MapEntry<DocumentReference<Map<String, dynamic>>,
          Map<String, dynamic>>>[];

      for (final doc in docs) {
        if (remaining <= 0) break;
        final liveSnap = live[doc.reference];
        if (liveSnap == null || !liveSnap.exists) continue;
        final data = liveSnap.data() ?? <String, dynamic>{};
        final dueAmount = _resolveDueAmount(data);
        if (dueAmount <= 0) continue;

        final applied = remaining >= dueAmount ? dueAmount : remaining;
        if (applied <= 0) continue;

        final totalPrice = _parseDouble(data['total_price']);
        final newDue =
            (dueAmount - applied).clamp(0.0, totalPrice).toDouble();
        final isPaid = newDue <= 0;
        final paymentEvents = _appendPaymentEvent(data, applied, now);

        remaining -= applied;

        updates.add(
          MapEntry(doc.reference, {
            'is_deferred': true,
            'paid': isPaid,
            'due_amount': newDue,
            if (isPaid) 'settled_at': FieldValue.serverTimestamp(),
            'last_payment_at': now,
            'last_payment_amount': applied,
            'payment_events': paymentEvents,
          }),
        );
      }

      for (final update in updates) {
        transaction.update(update.key, update.value);
      }
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchPaymentEventsForRange({
    required DateTimeRange range,
  }) async {
    final snap = await _firestore
        .collection('sales')
        .where(
          'last_payment_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('last_payment_at', isLessThan: Timestamp.fromDate(range.end))
        .get();
    return snap.docs;
  }

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  DateTime? _parseDateTime(dynamic value) {
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
      return DateTime.tryParse(value);
    }
    return null;
  }

  double _resolveDueAmount(Map<String, dynamic> data) {
    final raw = data['due_amount'];
    final dueAmount = _parseDouble(raw);
    final totalPrice = _parseDouble(data['total_price']);
    if (dueAmount > 0) {
      if (totalPrice > 0 && dueAmount > totalPrice) {
        return totalPrice;
      }
      return dueAmount;
    }
    if ((data['is_deferred'] == true || data['is_credit'] == true) &&
        data['paid'] != true) {
      return totalPrice;
    }
    return 0;
  }

  List<Map<String, dynamic>> _appendPaymentEvent(
    Map<String, dynamic> data,
    double amount,
    Timestamp at,
  ) {
    final raw = data['payment_events'];
    final List<Map<String, dynamic>> existing = [];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map) {
          existing.add(entry.cast<String, dynamic>());
        }
      }
    }
    existing.add({
      'amount': amount,
      'at': at,
    });
    return existing;
  }

  DateTime? _latestPaymentAt(Map<String, dynamic> data) {
    DateTime? latest;

    void consider(dynamic value) {
      final parsed = _parseDateTime(value);
      if (parsed == null) return;
      if (latest == null || parsed.isAfter(latest!)) {
        latest = parsed;
      }
    }

    final rawEvents = data['payment_events'];
    if (rawEvents is List) {
      for (final entry in rawEvents) {
        if (entry is Map) {
          consider(entry['at']);
        }
      }
    }

    consider(data['last_payment_at']);

    final isDeferred =
        data['is_deferred'] == true || data['is_credit'] == true;
    if (isDeferred && data['paid'] == true) {
      consider(data['settled_at']);
    }

    return latest;
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
