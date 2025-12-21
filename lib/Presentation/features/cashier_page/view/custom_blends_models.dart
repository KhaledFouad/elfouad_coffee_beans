part of 'custom_blends_page.dart';

class UserFriendly implements Exception {
  final String message;
  UserFriendly(this.message);
  @override
  String toString() => message;
}

/// مصدر الصنف (Singles أو Blends)
enum ItemSource { singles, blends }

/// ====== موديل صنف (منفرد أو توليفة جاهزة) موحد ======
class SingleVariantItem {
  final String id;
  final ItemSource source;
  final String name;
  final String variant; // قد تكون ""
  final String image;
  final double sellPricePerKg;
  final double costPricePerKg;
  final double stock; // جرام
  final String unit; // "g"

  // التحويج من الداتابيز
  final double spicesPricePerKg; // سعر التحويج/كجم
  final double spicesCostPerKg; // تكلفة التحويج/كجم
  final bool supportsSpice; // يدعم التحويج؟

  String get fullLabel => variant.isNotEmpty ? '$name - $variant' : name;
  double get sellPerG => sellPricePerKg / 1000.0;
  double get costPerG => costPricePerKg / 1000.0;

  SingleVariantItem({
    required this.id,
    required this.source,
    required this.name,
    required this.variant,
    required this.image,
    required this.sellPricePerKg,
    required this.costPricePerKg,
    required this.stock,
    required this.unit,
    required this.spicesPricePerKg,
    required this.spicesCostPerKg,
    required this.supportsSpice,
  });

  static double _readNum(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0.0;
  }

  static bool _readBool(dynamic v) => v == true;

  factory SingleVariantItem.fromSinglesDoc(
    DocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final m = d.data() ?? {};
    return SingleVariantItem(
      id: d.id,
      source: ItemSource.singles,
      name: (m['name'] ?? '').toString(),
      variant: (m['variant'] ?? '').toString(),
      image: (m['image'] ?? 'assets/singles.jpg').toString(),
      sellPricePerKg: _readNum(m['sellPricePerKg']),
      costPricePerKg: _readNum(m['costPricePerKg']),
      stock: _readNum(m['stock']),
      unit: (m['unit'] ?? 'g').toString(),
      spicesPricePerKg: _readNum(m['spicesPrice']),
      spicesCostPerKg: _readNum(m['spicesCost']),
      supportsSpice:
          _readBool(m['supportsSpice']) ||
          _readNum(m['spicesPrice']) > 0 ||
          _readNum(m['spicesCost']) > 0,
    );
  }

  factory SingleVariantItem.fromBlendsDoc(
    DocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final m = d.data() ?? {};
    return SingleVariantItem(
      id: d.id,
      source: ItemSource.blends,
      name: (m['name'] ?? '').toString(),
      variant: (m['variant'] ?? '').toString(),
      image: (m['image'] ?? 'assets/blends.jpg').toString(),
      sellPricePerKg: _readNum(m['sellPricePerKg']),
      costPricePerKg: _readNum(m['costPricePerKg']),
      stock: _readNum(m['stock']),
      unit: (m['unit'] ?? 'g').toString(),
      spicesPricePerKg: _readNum(m['spicesPrice']),
      spicesCostPerKg: _readNum(m['spicesCost']),
      supportsSpice:
          _readBool(m['supportsSpice']) ||
          _readNum(m['spicesPrice']) > 0 ||
          _readNum(m['spicesCost']) > 0,
    );
  }
}

enum LineInputMode { grams, price }

/// ====== سطر داخل توليفة العميل ======
class _BlendLine {
  SingleVariantItem? item;
  LineInputMode mode = LineInputMode.grams;

  int grams = 0; // إدخال بالجرامات
  double price = 0.0; // إدخال بالسعر (بن فقط)

  int get gramsEffective {
    if (item == null) return 0;
    if (mode == LineInputMode.grams) return grams;
    final perG = item!.sellPerG;
    if (perG <= 0) return 0;
    return (price / perG).floor().clamp(0, 1000000);
    // السعر هنا يعتبر "بن" فقط بدون تحويج إضافي
  }

  double get linePrice {
    if (item == null) return 0.0;
    return item!.sellPerG * gramsEffective;
  }

  double get lineCost {
    if (item == null) return 0.0;
    return item!.costPerG * gramsEffective;
  }
}

enum _PadTargetType { none, lineGrams, linePrice }
