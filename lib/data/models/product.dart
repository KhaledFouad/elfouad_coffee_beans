class Product {
  final String id;
  final String name;
  final String variant;
  final String category;
  final String unit;
  final int stock;
  final int minLevel;
  final double sellPrice;
  final double costPrice;

  Product({
    required this.id,
    required this.name,
    required this.variant,
    required this.category,
    required this.unit,
    required this.stock,
    required this.minLevel,
    required this.sellPrice,
    required this.costPrice,
  });

  factory Product.fromFirestore(Map<String, dynamic> data, String docId) {
    return Product(
      id: docId,
      name: data['name'] ?? '',
      variant: data['variant'] ?? '',
      category: data['category'] ?? '',
      unit: data['unit'] ?? '',
      stock: data['stock'] ?? 0,
      minLevel: data['minLevel'] ?? 0,
      sellPrice: (data['sellPrice'] ?? 0).toDouble(),
      costPrice: (data['costPrice'] ?? 0).toDouble(),
    );
  }
}
