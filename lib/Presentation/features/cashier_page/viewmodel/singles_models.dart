class SingleGroup {
  final String name;
  final String image;
  final int posOrder;
  final Map<String, SingleVariant> variants;

  SingleGroup({
    required this.name,
    required this.image,
    this.posOrder = 999999,
    Map<String, SingleVariant>? variants,
  }) : variants = variants ?? {};
}

class SingleVariant {
  final String id;
  final String name;
  final String variant; // "فاتح" / "وسط" / "غامق" أو ""
  final String image;
  final int posOrder;
  final double sellPricePerKg;
  final double costPricePerKg;
  final String unit; // غالبًا "g"

  SingleVariant({
    required this.id,
    required this.name,
    required this.variant,
    required this.image,
    required this.posOrder,
    required this.sellPricePerKg,
    required this.costPricePerKg,
    required this.unit,
  });
}
