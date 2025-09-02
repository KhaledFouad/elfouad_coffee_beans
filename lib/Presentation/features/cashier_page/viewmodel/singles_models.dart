class SingleGroup {
  final String name;
  final String image;
  final Map<String, SingleVariant> variants;

  SingleGroup({
    required this.name,
    required this.image,
    Map<String, SingleVariant>? variants,
  }) : variants = variants ?? {};
}

class SingleVariant {
  final String id;
  final String name;
  final String variant; // "فاتح" / "وسط" / "غامق" أو ""
  final String image;
  final double sellPricePerKg;
  final double costPricePerKg;
  final String unit; // غالبًا "g"

  SingleVariant({
    required this.id,
    required this.name,
    required this.variant,
    required this.image,
    required this.sellPricePerKg,
    required this.costPricePerKg,
    required this.unit,
  });
}
