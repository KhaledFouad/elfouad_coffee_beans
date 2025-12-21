part of 'cart_state.dart';

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
    // على الويب 1 << 32 يرجع 0، فبنستخدم حد آمن متوافق
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
