// lib/core/pricing/hawaj_helper.dart
/// أسماء المشروبات بالنكهات اللي ما بتتحوّجش
const Set<String> kFlavoredNames = {
  'قهوة كراميل',
  'قهوة بندق',
  'قهوة بندق قطع',
  'قهوة شوكلت',
  'قهوة فانيليا',
  'قهوة توت',
  'قهوة فراولة',
  'قهوة مانجو',
};

/// توليفات جاهزة مستثناة من التحويج
const Set<String> kReadyBlendExcluded = {
  'توليفة فرنساوي',
  'شاي كيني',
  'كوفى ميكس',
  ' قهوة تخسيس',
  'نسكافيه كلاسيك ',
};

/// سعر التحويج للأصناف المنفردة (ج/كجم) حسب الاسم
double hawajRatePerKgForSingle(String name) {
  final n = name.trim();
  if (n.contains('كولومبي')) return 80;
  if (n.contains('برازيلي')) return 60;
  if (n.contains('حبشي')) return 60;
  if (n.contains('هندي')) return 60;
  return 40; // الافتراضي لباقي الأصناف
}

/// سعر التحويج للتوليفات الجاهزة (ج/كجم)
double hawajRatePerKgForReadyBlend(String name) {
  final n = name.trim();
  if (kReadyBlendExcluded.contains(n)) return 0; // فرنساوي مستثنى
  return 40;
}

/// سعر التحويج لتوليفة العميل
double hawajRatePerKgForCustomBlend() => 50;

/// قيمة التحويج بالجنيه لوزن بالـ grams
double hawajAmountForGrams({required double grams, required double ratePerKg}) {
  if (grams <= 0 || ratePerKg <= 0) return 0;
  return (grams / 1000.0) * ratePerKg;
}
