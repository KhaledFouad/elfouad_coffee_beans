// lib/data/datasources/seedSingles.dart
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedSingles() async {
  print("🚀 Seeding singles (per-KG pricing, stock in grams)...");
  final db = FirebaseFirestore.instance;
  final col = db.collection('singles');
  final batch = db.batch();

  final List<Map<String, dynamic>> rows = [
    {
      "name": "هندي أرابيكا",
      "variant": "فاتح",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "هندي أرابيكا",
      "variant": "وسط",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "هندي أرابيكا",
      "variant": "غامق",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },

    // === هندي روبوستا ===
    {
      "name": "هندي روبوستا",
      "variant": "فاتح",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "هندي روبوستا",
      "variant": "وسط",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "هندي روبوستا",
      "variant": "غامق",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },

    // === اندونيسي 45 ===
    {
      "name": "اندونيسي 45",
      "variant": "فاتح",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "اندونيسي 45",
      "variant": "وسط",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "اندونيسي 45",
      "variant": "غامق",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },

    // === اندونيسي XL ===
    {
      "name": "اندونيسي XL",
      "variant": "فاتح",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "اندونيسي XL",
      "variant": "وسط",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "اندونيسي XL",
      "variant": "غامق",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },

    // === فيتنامي ===
    {
      "name": "فيتنامي",
      "variant": "فاتح",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "فيتنامي",
      "variant": "وسط",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "فيتنامي",
      "variant": "غامق",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },

    // === حبشي ===
    {
      "name": "حبشي",
      "variant": "فاتح",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "حبشي",
      "variant": "وسط",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "حبشي",
      "variant": "غامق",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },

    // === برازيلي ريو ===
    {
      "name": "برازيلي ريو",
      "variant": "فاتح",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "برازيلي ريو",
      "variant": "وسط",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "برازيلي ريو",
      "variant": "غامق",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },

    // === كولومبي ===
    {
      "name": "كولومبي",
      "variant": "فاتح",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "كولومبي",
      "variant": "وسط",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "كولومبي",
      "variant": "غامق",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },

    // === برازيلي سانتوس ===
    {
      "name": "برازيلي سانتوس",
      "variant": "فاتح",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "برازيلي سانتوس",
      "variant": "وسط",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "برازيلي سانتوس",
      "variant": "غامق",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },

    // === جواتيمالي ===
    {
      "name": "جواتيمالي",
      "variant": "فاتح",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "جواتيمالي",
      "variant": "وسط",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "جواتيمالي",
      "variant": "غامق",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },

    // === يمني ===
    {
      "name": "يمني",
      "variant": "فاتح",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "يمني",
      "variant": "وسط",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
    {
      "name": "يمني",
      "variant": "غامق",
      "unit": "g",
      "stock": 5000,
      "minLevel": 500,
      "sellPrice": 200,
      "costPrice": 150,
    },
  ];

  for (final p in rows) {
    final doc = col.doc();
    batch.set(doc, {
      'name': p['name'],
      'variant': p['variant'] ?? '',
      'category': 'أصناف منفردة',
      'unit': 'g', // نخزنها مرجعية
      'stock': p['stock'] ?? 0, // جرامات
      'minLevel': p['minLevel'] ?? 0,
      'sellPricePerKg': (p['sellPrice'] as num).toDouble(),
      'costPricePerKg': (p['costPrice'] as num).toDouble(),
      'image': p['image'] ?? 'assets/singles.jpg',
      'createdAt': DateTime.now().toUtc(),
    });
  }

  await batch.commit();
  print("🎉 Done! Seeded ${rows.length} singles.");
}
