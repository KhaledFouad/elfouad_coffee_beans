import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Represents how much stock to deduct from a Firestore document.
class StockImpact {
  const StockImpact({
    required this.collection,
    required this.docId,
    required this.field,
    required this.amount,
    this.label,
  });

  final String collection;
  final String docId;
  final String field; // e.g. stock, stock_units
  final double amount; // always positive
  final String? label;

  String get key => '$collection::$docId::$field';

  StockImpact mergeWith(StockImpact other) {
    return StockImpact(
      collection: collection,
      docId: docId,
      field: field,
      amount: amount + other.amount,
      label: label ?? other.label,
    );
  }
}

/// A line inside the in-progress invoice/cart.
class CartLine {
  CartLine({
    required this.id,
    required this.productId,
    required this.name,
    required this.type,
    required this.unit,
    required this.image,
    required this.quantity,
    required this.grams,
    required this.unitPrice,
    required this.unitCost,
    required this.lineTotalPrice,
    required this.lineTotalCost,
    this.variant,
    this.isComplimentary = false,
    this.isDeferred = false,
    this.note = '',
    this.meta = const {},
    this.impacts = const [],
  });

  final String id;
  final String productId;
  final String name;
  final String? variant;
  final String type; // drink, single, ready_blend, extra, custom_blend, invoice
  final String unit; // cup | g | piece
  final String image;
  final double quantity;
  final double grams;
  final double unitPrice;
  final double unitCost;
  final double lineTotalPrice;
  final double lineTotalCost;
  final bool isComplimentary;
  final bool isDeferred;
  final String note;
  final Map<String, dynamic> meta;
  final List<StockImpact> impacts;

  static final _rand = Random();

  static String newId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    // Ø¹Ù„Ù‰ Ø§Ù„ÙˆÙŠØ¨ 1 << 32 ÙŠØ±Ø¬Ø¹ 0ØŒ ÙØ¨Ù†Ø³ØªØ®Ø¯Ù… Ø­Ø¯ Ø¢Ù…Ù† Ù…ØªÙˆØ§ÙÙ‚
    final salt = _rand.nextInt(0x7fffffff);
    return '$ts-$salt';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'variant': variant,
      'type': type,
      'unit': unit,
      'qty': quantity,
      'grams': grams,
      'unit_price': unitPrice,
      'unit_cost': unitCost,
      'line_total_price': lineTotalPrice,
      'line_total_cost': lineTotalCost,
      'is_complimentary': isComplimentary,
      'is_deferred': isDeferred,
      'note': note,
      'meta': meta,
    };
  }

  CartLine copyWith({
    String? id,
    String? productId,
    String? name,
    String? variant,
    String? type,
    String? unit,
    String? image,
    double? quantity,
    double? grams,
    double? unitPrice,
    double? unitCost,
    double? lineTotalPrice,
    double? lineTotalCost,
    bool? isComplimentary,
    bool? isDeferred,
    String? note,
    Map<String, dynamic>? meta,
    List<StockImpact>? impacts,
  }) {
    return CartLine(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      variant: variant ?? this.variant,
      type: type ?? this.type,
      unit: unit ?? this.unit,
      image: image ?? this.image,
      quantity: quantity ?? this.quantity,
      grams: grams ?? this.grams,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCost: unitCost ?? this.unitCost,
      lineTotalPrice: lineTotalPrice ?? this.lineTotalPrice,
      lineTotalCost: lineTotalCost ?? this.lineTotalCost,
      isComplimentary: isComplimentary ?? this.isComplimentary,
      isDeferred: isDeferred ?? this.isDeferred,
      note: note ?? this.note,
      meta: meta ?? this.meta,
      impacts: impacts ?? this.impacts,
    );
  }
}

/// Simple cart controller that tracks the current invoice being built.
class CartState extends ChangeNotifier {
  final List<CartLine> _lines = [];
  bool _invoiceDeferred = false;
  String _invoiceNote = '';
  String _paymentMethod = 'cash';

  List<CartLine> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;

  double get totalPrice =>
      _lines.fold<double>(0, (acc, l) => acc + l.lineTotalPrice);
  double get totalCost =>
      _lines.fold<double>(0, (acc, l) => acc + l.lineTotalCost);
  double get totalProfit => totalPrice - totalCost;

  bool get invoiceDeferred => _invoiceDeferred;
  String get invoiceNote => _invoiceNote;
  String get paymentMethod => _paymentMethod;

  void addLine(CartLine line) {
    _lines.add(line);
    notifyListeners();
  }

  void removeLine(String id) {
    _lines.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _invoiceDeferred = false;
    _invoiceNote = '';
    _paymentMethod = 'cash';
    notifyListeners();
  }

  void setInvoiceDeferred(bool value) {
    _invoiceDeferred = value;
    notifyListeners();
  }

  void setInvoiceNote(String value) {
    _invoiceNote = value;
    notifyListeners();
  }

  void setPaymentMethod(String value) {
    _paymentMethod = value;
    notifyListeners();
  }
}

/// Commits all lines in the cart as a single invoice inside the sales collection.
class CartCheckout {
  CartCheckout._();

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

static Future<String> commitInvoice({
    required CartState cart,
    FirebaseFirestore? firestore,
  }) async {
    if (cart.isEmpty) {
      throw StateError('السلة فارغة، أضف عناصر أولاً.');
    }

    final db = firestore ?? FirebaseFirestore.instance;
    final invoiceRef = db.collection('sales').doc();

    // دمج تأثيرات المخزون لنفس الصنف في Impact واحد
    final mergedImpacts = <String, StockImpact>{};
    for (final line in cart.lines) {
      for (final imp in line.impacts) {
        final existing = mergedImpacts[imp.key];
        mergedImpacts[imp.key] =
            existing == null ? imp : existing.mergeWith(imp);
      }
    }

    final totalPrice = cart.totalPrice;
    final totalCost = cart.totalCost;
    final profit = totalPrice - totalCost;
    final isDeferred = cart.invoiceDeferred;
    final note = cart.invoiceNote.trim();

    await db.runTransaction((tx) async {
      // ===== 1) اقرأ كل مستندات المخزون واحسب القيم الجديدة (بدون أي كتابة) =====
      final Map<String, double> newValues = {};
      final Map<String, DocumentReference<Map<String, dynamic>>> refs = {};

      for (final impact in mergedImpacts.values) {
        final ref = db.collection(impact.collection).doc(impact.docId);
        refs[impact.key] = ref;

        final snap = await tx.get(ref);

        if (!snap.exists) {
          throw Exception(
            'الصنف غير موجود في المخزون (${impact.label ?? impact.docId}).',
          );
        }

        final data = snap.data() as Map<String, dynamic>;
        final current = _asDouble(data[impact.field]);

        if (current < impact.amount) {
          final remaining = current.toStringAsFixed(0);
          final need = impact.amount.toStringAsFixed(0);
          throw Exception(
            'المخزون غير كافٍ'
            '${impact.label != null ? ' لـ ${impact.label}' : ''}. '
            'المتاح: $remaining • المطلوب: $need',
          );
        }

        newValues[impact.key] = current - impact.amount;
      }

      // ===== 2) اكتب كل التحديثات بعد الانتهاء من كل القراءات =====
      newValues.forEach((key, value) {
        final impact = mergedImpacts[key]!;
        final ref = refs[key]!;
        tx.update(ref, {impact.field: value});
      });

      // ===== 3) احفظ الفاتورة =====
      tx.set(invoiceRef, {
        'type': 'invoice',
        'items': cart.lines.map((l) => l.toMap()).toList(),
        'total_price': totalPrice,
        'total_cost': totalCost,
        'profit_total': profit,
        'is_deferred': isDeferred,
        'paid': !isDeferred,
        'due_amount': isDeferred ? totalPrice : 0.0,
        'note': note,
        'payment_method': cart.paymentMethod,
        'source': 'pos_cart',
        'created_at': FieldValue.serverTimestamp(),
      });
    });

    return invoiceRef.id;
  }
}
