class BlendGroup {
  final String name;
  final String image;
  final Map<String, BlendVariant>
  variants; // key = variant ("فاتح"/"وسط"/"غامق"/"")

  BlendGroup({
    required this.name,
    required this.image,
    Map<String, BlendVariant>? variants,
  }) : variants = variants ?? {};
}

class BlendVariant {
  final String id;
  final String name;
  final String variant; // "فاتح" / "وسط" / "غامق" أو ""
  final String image;
  final double sellPricePerKg; // Number في Firestore
  final double costPricePerKg; // Number في Firestore
  final String unit; // غالبًا "g"
  final double stock; // جرامات

  BlendVariant({
    required this.id,
    required this.name,
    required this.variant,
    required this.image,
    required this.sellPricePerKg,
    required this.costPricePerKg,
    required this.unit,
    required this.stock,
  });
}
