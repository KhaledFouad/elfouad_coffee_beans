class BlendGroup {
  final String name;
  final String image;
  final int posOrder;
  final Map<String, BlendVariant>
  variants; // key = variant ("فاتح"/"وسط"/"غامق"/"")

  BlendGroup({
    required this.name,
    required this.image,
    this.posOrder = 999999,
    Map<String, BlendVariant>? variants,
  }) : variants = variants ?? {};
}

class BlendVariant {
  final String id;
  final String name;
  final String variant; // "فاتح" / "وسط" / "غامق" أو ""
  final String image;
  final int posOrder;
  final double sellPricePerKg; // Number في Firestore
  final double costPricePerKg; // Number في Firestore
  final String unit; // غالبًا "g"
  final double stock; // جرامات

  BlendVariant({
    required this.id,
    required this.name,
    required this.variant,
    required this.image,
    required this.posOrder,
    required this.sellPricePerKg,
    required this.costPricePerKg,
    required this.unit,
    required this.stock,
  });
}
