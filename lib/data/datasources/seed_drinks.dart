import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// سيّد مجموعة drinks بتكلفة ثابتة لكل كوب، بدون أي اعتماد على blends.
/// تقدر تعدّل الأسعار/التكاليف/الصور والـ roastLevels من المصفوفة تحت.
Future<void> seedDrinksFixed() async {
  final db = FirebaseFirestore.instance;
  final batch = db.batch();

  debugPrint('🚀 Seeding drinks (fixed per-cup cost)…');

  // === عرّف مشروباتك هنا ===
  final List<Map<String, dynamic>> drinks = [
    // له درجات تحميص (التكلفة ثابتة لكل الدرجات)
    {
      'name': 'قهوة تركي',
      'unit': 'cup',
      'sellPrice': 15.0,
      'costPrice': 8.00,
      'doubleCostPrice': 12.00, // 👈 تكلفة الدوبل (مختلفة عن 2x أحياناً)
      'doubleDiscount': 5.0, // 👈 خصم الدوبل على السعر (اختياري، الافتراضي 10)
      'image': 'assets/drinks.jpg',
      'roastLevels': ['فاتح', 'وسط', 'غامق'],
    },
    {
      'name': 'قهوة اسبريسو',
      'unit': 'cup',
      'sellPrice': 20.0,
      'costPrice': 7.0,
      'doubleCostPrice': 14.00, // 👈 تكلفة الدوبل للسبريسو
      'doubleDiscount': 10.0, // 👈 خصم الدوبل
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
    },
    {
      "name": "كوفي ميكس",
      "unit": "cup",
      "sellPrice": 15.0, // الافتراضي (مياه)
      "costPrice": 10.0, // لو عندك تكلفة حطها
      "image": "assets/drinks.jpg",
      "roastLevels": <String>[],
      "mixOptions": {
        // هنستعملها في الديالوج
        "waterPrice": 15.0,
        "milkPrice": 20.0,
      },
    },
    {
      "name": "شاي",
      "unit": "cup",
      "sellPrice": 7.0,
      "costPrice": 4.0,
      "image": "assets/drinks.jpg",
      "roastLevels": <String>[],
    },
    {
      "name": "مياه",
      "unit": "bottle",
      "sellPrice": 6.0,
      "costPrice": 3.5,
      "image": "assets/drinks.jpg",
      "roastLevels": <String>[],
    },

    {
      'name': 'قهوة فرنساوي',
      'unit': 'cup',
      'sellPrice': 25.0,
      'costPrice': 17.00,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
    },
    {
      'name': 'قهوة بندق',
      'unit': 'cup',
      'sellPrice': 25.0,
      'costPrice': 16.00,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
    },
    {
      'name': 'قهوة بندق قطع',
      'unit': 'cup',
      'sellPrice': 25.0,
      'costPrice': 17.50,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
    },
    {
      'name': 'قهوة شوكلت',
      'unit': 'cup',
      'sellPrice': 25.0,
      'costPrice': 16.00,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
    },
    {
      'name': 'قهوة فانيليا',
      'unit': 'cup',
      'sellPrice': 25.0,
      'costPrice': 16.00,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
    },
    {
      'name': 'قهوة كراميل',
      'unit': 'cup',
      'sellPrice': 25.0,
      'costPrice': 16.00,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
    },
    {
      'name': 'قهوة مانجو',
      'unit': 'cup',
      'sellPrice': 25.0,
      'costPrice': 16.00,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
    },
    {
      'name': 'قهوة توت',
      'unit': 'cup',
      'sellPrice': 25.0,
      'costPrice': 16.00,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
    },
    {
      'name': 'قهوة فراولة',
      'unit': 'cup',
      'sellPrice': 25.0,
      'costPrice': 16.00,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
    },
  ];

  // === كتابة الوثائق ===
  int added = 0;
  for (final d in drinks) {
    // تحويلات آمنة للأنواع
    final name = (d['name'] ?? '').toString();
    final unit = (d['unit'] ?? 'cup').toString();
    final image = (d['image'] ?? 'assets/drinks.jpg').toString();
    final sellPrice = (d['sellPrice'] is num)
        ? (d['sellPrice'] as num).toDouble()
        : double.tryParse(d['sellPrice'].toString()) ?? 0.0;
    final costPrice = (d['costPrice'] is num)
        ? (d['costPrice'] as num).toDouble()
        : double.tryParse(d['costPrice'].toString()) ?? 0.0;
    final roastLevels = (d['roastLevels'] is List)
        ? (d['roastLevels'] as List).map((e) => e.toString()).toList()
        : const <String>[];

    final ref = db.collection('drinks').doc(); // مستند جديد
    batch.set(ref, {
      'name': name,
      'unit': unit,
      'sellPrice': sellPrice,
      'costPrice': costPrice, // ✅ التكلفة الثابتة للكوب
      'image': image,
      'roastLevels': roastLevels, // إن لقيتها الديالوج هيعرضها
      'createdAt': DateTime.now().toUtc(),
    });

    debugPrint('✅ Drink added: $name | sell=$sellPrice | cost=$costPrice');
    added++;
  }

  await batch.commit();
  debugPrint('🎉 Done! Seeded $added drinks with fixed costs.');
}

/// (اختياري) امسح مجموعة drinks بالكامل قبل التسييد.
/// خلي بالك: الحذف على دفعات—استخدمها بحذر في بيئة التطوير فقط.
Future<void> clearDrinks({int pageSize = 400}) async {
  final db = FirebaseFirestore.instance;
  debugPrint('🧹 Clearing drinks collection…');
  while (true) {
    final snap = await db.collection('drinks').limit(pageSize).get();
    if (snap.docs.isEmpty) break;
    final batch = db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    debugPrint('…deleted ${snap.docs.length}');
  }
  debugPrint('✅ drinks cleared.');
}