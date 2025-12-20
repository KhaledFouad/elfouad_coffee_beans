import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
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
    // ├ÿ┬╣├ÖΓÇ₧├ÖΓÇ░ ├ÿ┬º├ÖΓÇ₧├Ö╦å├Ö┼á├ÿ┬¿ 1 << 32 ├Ö┼á├ÿ┬▒├ÿ┬¼├ÿ┬╣ 0├ÿ┼Æ ├Ö┬ü├ÿ┬¿├ÖΓÇá├ÿ┬│├ÿ┬¬├ÿ┬«├ÿ┬»├ÖΓÇª ├ÿ┬¡├ÿ┬» ├ÿ┬ó├ÖΓÇª├ÖΓÇá ├ÖΓÇª├ÿ┬¬├Ö╦å├ÿ┬º├Ö┬ü├ÖΓÇÜ
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
  bool _invoiceComplimentary = false;
  String _invoiceNote = '';
  String _paymentMethod = 'cash';

  List<CartLine> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;

  double get totalPrice =>
      _lines.fold<double>(0, (acc, l) => acc + l.lineTotalPrice);
  double get totalCost =>
      _lines.fold<double>(0, (acc, l) => acc + l.lineTotalCost);
  double get totalProfit {
    if (_invoiceComplimentary) return 0.0;
    return _lines.fold<double>(0.0, (acc, line) {
      if (line.isComplimentary) return acc;
      return acc + (line.lineTotalPrice - line.lineTotalCost);
    });
  }

  bool get invoiceDeferred => _invoiceDeferred;
  bool get invoiceComplimentary => _invoiceComplimentary;
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
    _invoiceComplimentary = false;
    _invoiceNote = '';
    _paymentMethod = 'cash';
    notifyListeners();
  }

  void setInvoiceDeferred(bool value) {
    _invoiceDeferred = value;
    if (value) {
      _invoiceComplimentary = false;
    }
    notifyListeners();
  }

  void setInvoiceComplimentary(bool value) {
    _invoiceComplimentary = value;
    if (value) {
      _invoiceDeferred = false;
      _invoiceNote = '';
    }
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

class _CustomBlendWrite {
  _CustomBlendWrite({
    required this.title,
    required this.components,
    required this.totalGrams,
    required this.totalPrice,
    required this.spiced,
    required this.ginsengGrams,
    required this.isComplimentary,
    required this.isDeferred,
    required this.source,
    required this.isInvoice,
  });

  final String title;
  final List<dynamic> components;
  final double totalGrams;
  final double totalPrice;
  final bool spiced;
  final int ginsengGrams;
  final bool isComplimentary;
  final bool isDeferred;
  final String source;
  final bool isInvoice;
}

/// Commits cart lines to the sales collection.
/// If the cart has one line, stores it as the item type instead of an invoice.
class CartCheckout {
  CartCheckout._();

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    final raw = v?.toString() ?? '';
    if (raw.isEmpty) return 0.0;
    final normalized = _normalizeNumberString(raw);
    return double.tryParse(normalized) ?? 0.0;
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return _asDouble(v).toInt();
  }

  static String _normalizeNumberString(String input) {
    final buffer = StringBuffer();
    for (final unit in input.runes) {
      switch (unit) {
        case 0x0660:
          buffer.write('0');
          continue;
        case 0x0661:
          buffer.write('1');
          continue;
        case 0x0662:
          buffer.write('2');
          continue;
        case 0x0663:
          buffer.write('3');
          continue;
        case 0x0664:
          buffer.write('4');
          continue;
        case 0x0665:
          buffer.write('5');
          continue;
        case 0x0666:
          buffer.write('6');
          continue;
        case 0x0667:
          buffer.write('7');
          continue;
        case 0x0668:
          buffer.write('8');
          continue;
        case 0x0669:
          buffer.write('9');
          continue;
        case 0x06F0:
          buffer.write('0');
          continue;
        case 0x06F1:
          buffer.write('1');
          continue;
        case 0x06F2:
          buffer.write('2');
          continue;
        case 0x06F3:
          buffer.write('3');
          continue;
        case 0x06F4:
          buffer.write('4');
          continue;
        case 0x06F5:
          buffer.write('5');
          continue;
        case 0x06F6:
          buffer.write('6');
          continue;
        case 0x06F7:
          buffer.write('7');
          continue;
        case 0x06F8:
          buffer.write('8');
          continue;
        case 0x06F9:
          buffer.write('9');
          continue;
        case 0x066B: // Arabic decimal separator
          buffer.write('.');
          continue;
        case 0x066C: // Arabic thousands separator
          continue;
      }
      final ch = String.fromCharCode(unit);
      if ((ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0) ||
          ch == '.' ||
          ch == '-') {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  static String _normalizeTitle(String raw) => raw.trim();

  static dynamic _sanitizeValue(dynamic value) {
    if (value is double) {
      return value.isFinite ? value : 0.0;
    }
    if (value is num) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitizeValue(v)));
    }
    if (value is Iterable) {
      return value.map(_sanitizeValue).toList();
    }
    return value;
  }

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> input) {
    return input.map((key, value) => MapEntry(key, _sanitizeValue(value)));
  }

  static Future<Map<String, DocumentReference<Map<String, dynamic>>>>
  _resolveCustomBlendRefs(FirebaseFirestore db, Iterable<String> titles) async {
    final refs = <String, DocumentReference<Map<String, dynamic>>>{};
    for (final raw in titles) {
      final title = _normalizeTitle(raw);
      if (title.isEmpty || refs.containsKey(title)) continue;
      final snap = await db
          .collection('custom_blends')
          .where('title', isEqualTo: title)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        refs[title] = snap.docs.first.reference;
      } else {
        refs[title] = db.collection('custom_blends').doc();
      }
    }
    return refs;
  }

  static Future<void> _preflightImpacts(
    FirebaseFirestore db,
    Map<String, StockImpact> mergedImpacts,
  ) async {
    for (final impact in mergedImpacts.values) {
      final amount = impact.amount;
      if (!amount.isFinite || amount <= 0) {
        throw StateError(
          'Invalid stock amount for ${impact.label ?? impact.docId}.',
        );
      }
      final ref = db.collection(impact.collection).doc(impact.docId);
      final snap = await ref.get();
      if (!snap.exists) {
        throw StateError(
          'Missing stock item: ${impact.label ?? impact.docId}.',
        );
      }
      final data = snap.data() as Map<String, dynamic>;
      final current = _asDouble(data[impact.field]);
      if (!current.isFinite) {
        throw StateError(
          'Invalid stock value for ${impact.label ?? impact.docId}.',
        );
      }
      if (current < amount) {
        final remaining = current.toStringAsFixed(0);
        final need = amount.toStringAsFixed(0);
        throw StateError(
          '${AppStrings.errorStockNotEnoughSimple}'
          '${impact.label != null ? ' ?? ${impact.label}' : ''}. '
          '??????: $remaining   ???????: $need',
        );
      }
    }
  }

  static Future<String> commitInvoice({
    required CartState cart,
    FirebaseFirestore? firestore,
  }) async {
    if (cart.isEmpty) {
      throw StateError('${AppStrings.cartEmptyAddProductsFirst}.');
    }

    final db = firestore ?? FirebaseFirestore.instance;
    final saleRef = db.collection('sales').doc();

    // دمج تأثيرات المخزون لنفس الصنف في Impact واحد
    final mergedImpacts = <String, StockImpact>{};
    for (final line in cart.lines) {
      for (final imp in line.impacts) {
        final existing = mergedImpacts[imp.key];
        mergedImpacts[imp.key] = existing == null
            ? imp
            : existing.mergeWith(imp);
      }
    }

    final isSingleLine = cart.lines.length == 1;
    final CartLine? singleLine = isSingleLine ? cart.lines.first : null;
    final lineComplimentary = singleLine?.isComplimentary ?? false;
    final lineDeferred = singleLine?.isDeferred ?? false;

    final isComplimentary = isSingleLine
        ? (cart.invoiceComplimentary || lineComplimentary)
        : cart.invoiceComplimentary;

    final isDeferred =
        (isSingleLine
            ? (cart.invoiceDeferred || lineDeferred)
            : cart.invoiceDeferred) &&
        !isComplimentary;

    final note = isDeferred
        ? (cart.invoiceNote.trim().isNotEmpty
              ? cart.invoiceNote.trim()
              : (singleLine?.note.trim() ?? ''))
        : '';

    final totalCost = isSingleLine ? singleLine!.lineTotalCost : cart.totalCost;
    final totalPrice = isComplimentary
        ? 0.0
        : (isSingleLine ? singleLine!.lineTotalPrice : cart.totalPrice);
    final double profit;
    if (isComplimentary) {
      profit = 0.0;
    } else if (isSingleLine) {
      profit = totalPrice - totalCost;
    } else {
      profit = cart.lines.fold<double>(0.0, (acc, line) {
        if (line.isComplimentary) return acc;
        return acc + (line.lineTotalPrice - line.lineTotalCost);
      });
    }

    final customBlendWrites = <_CustomBlendWrite>[];
    if (isSingleLine && singleLine!.type == 'custom_blend') {
      final line = singleLine;
      final title = _normalizeTitle(
        (line.meta['custom_title'] ?? line.variant ?? line.name).toString(),
      );
      final components = line.meta['components'];
      if (title.isNotEmpty) {
        customBlendWrites.add(
          _CustomBlendWrite(
            title: title,
            components: components is List ? components : const [],
            totalGrams: line.grams,
            totalPrice: totalPrice,
            spiced: line.meta['spiced'] == true,
            ginsengGrams: _asInt(line.meta['ginseng_grams']),
            isComplimentary: isComplimentary,
            isDeferred: isDeferred,
            source: 'pos_cart',
            isInvoice: false,
          ),
        );
      }
    } else if (!isSingleLine) {
      for (final line in cart.lines) {
        if (line.type != 'custom_blend') continue;
        final title = _normalizeTitle(
          (line.meta['custom_title'] ?? line.variant ?? line.name).toString(),
        );
        if (title.isEmpty) continue;
        final lineComplimentary = isComplimentary || line.isComplimentary;
        final totalPriceOut = lineComplimentary ? 0.0 : line.lineTotalPrice;
        final components = line.meta['components'];
        customBlendWrites.add(
          _CustomBlendWrite(
            title: title,
            components: components is List ? components : const [],
            totalGrams: line.grams,
            totalPrice: totalPriceOut,
            spiced: line.meta['spiced'] == true,
            ginsengGrams: _asInt(line.meta['ginseng_grams']),
            isComplimentary: lineComplimentary,
            isDeferred: isDeferred,
            source: 'pos_cart',
            isInvoice: true,
          ),
        );
      }
    }

    final customBlendRefs = await _resolveCustomBlendRefs(
      db,
      customBlendWrites.map((e) => e.title),
    );

    if (mergedImpacts.isNotEmpty) {
      await _preflightImpacts(db, mergedImpacts);
    }

    String? validationError;

    await db.runTransaction((tx) async {
      // ===== 1) اقرأ كل مستندات المخزون واحسب القيم الجديدة (بدون أي كتابة) =====
      final Map<String, double> newValues = {};
      final Map<String, DocumentReference<Map<String, dynamic>>> refs = {};

      for (final impact in mergedImpacts.values) {
        if (validationError != null) return;
        if (!impact.amount.isFinite || impact.amount <= 0) {
          validationError =
              'Invalid stock amount for ${impact.label ?? impact.docId}.';
          return;
        }
        final ref = db.collection(impact.collection).doc(impact.docId);
        refs[impact.key] = ref;

        final snap = await tx.get(ref);

        if (!snap.exists) {
          validationError =
              'Missing stock item: ${impact.label ?? impact.docId}.';
          return;
        }

        final data = snap.data() as Map<String, dynamic>;
        final current = _asDouble(data[impact.field]);

        if (!current.isFinite) {
          validationError =
              'Invalid stock value for ${impact.label ?? impact.docId}.';
          return;
        }

        if (current < impact.amount) {
          final remaining = current.toStringAsFixed(0);
          final need = impact.amount.toStringAsFixed(0);
          validationError =
              '${AppStrings.errorStockNotEnoughSimple}'
              '${impact.label != null ? ' ?? ${impact.label}' : ''}. '
              '??????: $remaining   ???????: $need';
          return;
        }

        newValues[impact.key] = current - impact.amount;
      }

      if (validationError != null) return;

      // Read invoice counter before any writes (Firestore requires reads first).
      DocumentReference<Map<String, dynamic>>? counterRef;
      int? nextInvoiceNumber;
      if (!isSingleLine) {
        counterRef = db.collection('counters').doc('invoice_counter');
        final counterSnap = await tx.get(counterRef);
        final counterData = counterSnap.data();
        final currentNumber = counterData == null
            ? 0
            : _asInt(counterData['last_invoice_number']);
        nextInvoiceNumber = currentNumber + 1;
      }

      // ===== 2) اكتب كل التحديثات بعد الانتهاء من كل القراءات =====
      newValues.forEach((key, value) {
        final impact = mergedImpacts[key]!;
        final ref = refs[key]!;
        tx.update(ref, {impact.field: value});
      });

      // ===== 3) احفظ الفاتورة =====
      if (isSingleLine) {
        final line = singleLine!;
        final unitPriceOut = isComplimentary ? 0.0 : line.unitPrice;
        final totalPriceOut = isComplimentary ? 0.0 : line.lineTotalPrice;
        final customTitle = line.type == 'custom_blend'
            ? (line.meta['custom_title'] ?? line.variant ?? line.name)
                  .toString()
                  .trim()
            : '';
        final customComponents = line.type == 'custom_blend'
            ? line.meta['components']
            : null;

        final data = <String, dynamic>{
          'type': line.type,
          'source': 'pos_cart',
          'name': line.name,
          'variant': line.variant,
          'unit': line.unit,
          'quantity': line.quantity,
          'grams': line.grams,
          'unit_price': unitPriceOut,
          'unit_cost': line.unitCost,
          'total_price': totalPriceOut,
          'total_cost': line.lineTotalCost,
          'profit_total': profit,
          'is_complimentary': isComplimentary,
          'is_deferred': isDeferred,
          'paid': !isDeferred,
          'due_amount': isDeferred ? totalPriceOut : 0.0,
          'note': note,
          'payment_method': cart.paymentMethod,
          'meta': line.meta,
          'created_at': FieldValue.serverTimestamp(),
        };

        if (line.type == 'drink') {
          data['drink_id'] = line.productId;
          data['drink_name'] = line.name;
        } else if (line.type == 'single') {
          data['single_id'] = line.productId;
          data['single_name'] = line.name;
        } else if (line.type == 'ready_blend') {
          data['blend_id'] = line.productId;
          data['blend_name'] = line.name;
        } else if (line.type == 'extra') {
          data['extra_id'] = line.productId;
          data['extra_name'] = line.name;
        } else if (line.type == 'custom_blend') {
          if (customTitle.isNotEmpty) {
            data['custom_title'] = customTitle;
          }
          if (customComponents is List) {
            data['components'] = customComponents;
          }
        }

        final sanitizedData = _sanitizeMap(data);
        tx.set(saleRef, sanitizedData);
        if (line.type == 'custom_blend' && customTitle.isNotEmpty) {
          final blendRef = customBlendRefs[customTitle];
          if (blendRef != null) {
            final blendData = _sanitizeMap({
              'title': customTitle,
              'created_at': FieldValue.serverTimestamp(),
              'components': customComponents is List
                  ? customComponents
                  : const [],
              'total_grams': line.grams,
              'total_price': totalPriceOut,
              'spiced': line.meta['spiced'] == true,
              'ginseng_grams': _asInt(line.meta['ginseng_grams']),
              'is_complimentary': isComplimentary,
              'is_deferred': isDeferred,
              'sale_id': saleRef.id,
              'source': 'pos_cart',
            });
            tx.set(blendRef, blendData, SetOptions(merge: true));
          }
        }
      } else {
        final nextNumber = nextInvoiceNumber ?? 1;

        tx.set(counterRef!, {
          'last_invoice_number': nextNumber,
        }, SetOptions(merge: true));

        final items = cart.lines.map((l) {
          final map = _sanitizeMap(l.toMap());
          final lineComplimentary =
              isComplimentary || (map['is_complimentary'] == true);
          if (lineComplimentary) {
            map['unit_price'] = 0.0;
            map['line_total_price'] = 0.0;
            map['is_complimentary'] = true;
          }
          return map;
        }).toList();

        final invoiceData = _sanitizeMap({
          'type': 'invoice',
          'invoice_number': nextNumber,
          'items': items,
          'total_price': totalPrice,
          'total_cost': totalCost,
          'profit_total': profit,
          'is_complimentary': isComplimentary,
          'is_deferred': isDeferred,
          'paid': !isDeferred,
          'due_amount': isDeferred ? totalPrice : 0.0,
          'note': note,
          'payment_method': cart.paymentMethod,
          'source': 'pos_cart',
          'created_at': FieldValue.serverTimestamp(),
        });
        tx.set(saleRef, invoiceData);

        for (final write in customBlendWrites) {
          if (!write.isInvoice) continue;
          final blendRef = customBlendRefs[write.title];
          if (blendRef == null) continue;
          final blendData = _sanitizeMap({
            'title': write.title,
            'created_at': FieldValue.serverTimestamp(),
            'components': write.components,
            'total_grams': write.totalGrams,
            'total_price': write.totalPrice,
            'spiced': write.spiced,
            'ginseng_grams': write.ginsengGrams,
            'is_complimentary': write.isComplimentary,
            'is_deferred': write.isDeferred,
            'invoice_id': saleRef.id,
            'invoice_number': nextNumber,
            'source': write.source,
          });
          tx.set(blendRef, blendData, SetOptions(merge: true));
        }
      }
    });

    if (validationError != null) {
      throw StateError(validationError!);
    }

    return saleRef.id;
  }
}
