class Product {
  final String id;
  final String name;
  final String type; // drink | single | ready_blend | custom_blend
  final String? unit; // cup | gram
  final double? sellPricePerUnit;
  final double? costPricePerUnit;
  final double? sellPricePerGram;
  final double? costPricePerGram;
  final bool? isHawaijAvailable;
  final List<String>? roastLevels;

  Product({
    required this.id,
    required this.name,
    required this.type,
    this.unit,
    this.sellPricePerUnit,
    this.costPricePerUnit,
    this.sellPricePerGram,
    this.costPricePerGram,
    this.isHawaijAvailable,
    this.roastLevels,
  });

  factory Product.fromMap(String id, Map<String, dynamic> m) => Product(
    id: id,
    name: m['name'] ?? '',
    type: m['type'] ?? 'drink',
    unit: m['unit'],
    sellPricePerUnit: (m['sellPricePerUnit'] ?? 0).toDouble(),
    costPricePerUnit: (m['costPricePerUnit'] ?? 0).toDouble(),
    sellPricePerGram: (m['sellPricePerGram'] ?? 0).toDouble(),
    costPricePerGram: (m['costPricePerGram'] ?? 0).toDouble(),
    isHawaijAvailable: m['isHawaijAvailable'],
    roastLevels: (m['roastLevels'] as List?)?.map((e) => e.toString()).toList(),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type,
    'unit': unit,
    'sellPricePerUnit': sellPricePerUnit,
    'costPricePerUnit': costPricePerUnit,
    'sellPricePerGram': sellPricePerGram,
    'costPricePerGram': costPricePerGram,
    'isHawaijAvailable': isHawaijAvailable,
    'roastLevels': roastLevels,
  };
}
