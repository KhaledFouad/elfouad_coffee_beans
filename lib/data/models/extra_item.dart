import 'package:cloud_firestore/cloud_firestore.dart';

class ExtraItem {
  final String id;
  final String name;
  final String category;
  final String? variant;
  final String unit; // "piece"
  final double priceSell; // سعر البيع/قطعة
  final double costUnit; // تكلفة/قطعة
  final int stockUnits; // مخزون بالقطعة
  final bool active;

  ExtraItem({
    required this.id,
    required this.name,
    required this.category,
    this.variant,
    this.unit = 'piece',
    required this.priceSell,
    required this.costUnit,
    required this.stockUnits,
    this.active = true,
  });

  factory ExtraItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    double numValue(v) =>
        (v is num) ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;
    int intValue(v) => (v is num) ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

    return ExtraItem(
      id: d.id,
      name: (m['name'] ?? '').toString(),
      category: (m['category'] ?? '').toString(),
      variant: (m['variant'] as String?)?.trim(),
      unit: (m['unit'] ?? 'piece').toString(),
      priceSell: numValue(m['price_sell']),
      costUnit: numValue(m['cost_unit']),
      stockUnits: intValue(m['stock_units']),
      active: (m['active'] ?? true) == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'variant': variant,
    'unit': unit,
    'price_sell': priceSell,
    'cost_unit': costUnit,
    'stock_units': stockUnits,
    'active': active,
    'updated_at': FieldValue.serverTimestamp(),
  };
}
