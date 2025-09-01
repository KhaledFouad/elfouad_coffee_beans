import 'package:cloud_firestore/cloud_firestore.dart';

/// Key helper: name|variant (variant ممكن يبقى فاضي "")
String _k(String name, String? variant) =>
    '${name.trim()}|${(variant ?? '').trim()}';

Future<void> seedDrinks() async {
  print("🚀 Seeding drinks with IDs (no name-matching)...");
  final db = FirebaseFirestore.instance;

  // 1) اعمل Lookup من blends: name|variant -> {id, costPerGram}
  final blendsSnap = await db.collection('blends').get();
  final Map<String, Map<String, dynamic>> blendKey = {};
  for (final d in blendsSnap.docs) {
    final data = d.data();
    final k = _k(
      (data['name'] ?? '').toString(),
      (data['variant'] ?? '').toString(),
    );
    final costPerKg = (data['costPrice'] ?? 0).toDouble();
    blendKey[k] = {'id': d.id, 'costPerGram': costPerKg / 1000.0};
  }

  String idOf(String name, [String? variant]) {
    final k = _k(name, variant);
    final v = blendKey[k];
    if (v == null) {
      throw '❌ مفيش blend بالاسم "$name" والتحميص "${variant ?? ''}" — عدّل seed_blends أو الأسماء هنا.';
    }
    return v['id'] as String;
  }

  double cpg(String name, [String? variant]) {
    final k = _k(name, variant);
    final v = blendKey[k];
    if (v == null) return 0;
    return (v['costPerGram'] as double);
  }

  // 2) عرّف المشروبات بالمنطق (مش IDs) وبعدين نحولها لـ IDs
  final List<Map<String, dynamic>> drinksLogical = [
    // تركي (له درجات تحميص): 10g/كوب من "توليفة اسبيشيال"
    {
      'name': 'قهوة تركي',
      'unit': 'cup',
      'sellPrice': 15.0,
      'image': 'assets/drinks.jpg',
      'roastLevels': ['فاتح', 'وسط', 'غامق'],
      // نكتبها كمنطق اسم/تحميص، وهنحوّلها IDs تحت
      'perRoast': {
        'فاتح': {'توليفة اسبيشيال': 10},
        'وسط': {'توليفة اسبيشيال': 10},
        'غامق': {'توليفة اسبيشيال': 10},
      },
    },

    // اسبريسو: 8g/كوب من "توليفة اسبريسو" بدون تحميص
    {
      'name': 'قهوة اسبريسو',
      'unit': 'cup',
      'sellPrice': 20.0,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
      'consumes': {'توليفة اسبريسو': 8},
    },

    // فرنساوي: 15g/كوب من "توليفة فرنساوي"
    {
      'name': 'قهوة فرنساوي',
      'unit': 'cup',
      'sellPrice': 25.0,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
      'consumes': {'توليفة فرنساوي': 15},
    },

    // نكهات (20g/كوب)
    {
      'name': 'قهوة بندق',
      'unit': 'cup',
      'sellPrice': 25.0,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
      'consumes': {'قهوة بندق': 20},
    },
    {
      'name': 'قهوة بندق قطع',
      'unit': 'cup',
      'sellPrice': 25.0,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
      'consumes': {'قهوة بندق قطع': 20},
    },
    {
      'name': 'قهوة شوكلت',
      'unit': 'cup',
      'sellPrice': 25.0,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
      'consumes': {'قهوة شوكلت': 20},
    },
    {
      'name': 'قهوة فانيليا',
      'unit': 'cup',
      'sellPrice': 25.0,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
      'consumes': {'قهوة فانيليا': 20},
    },
    {
      'name': 'قهوة كراميل',
      'unit': 'cup',
      'sellPrice': 25.0,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
      'consumes': {'قهوة كراميل': 20},
    },
    {
      'name': 'قهوة مانجو',
      'unit': 'cup',
      'sellPrice': 25.0,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
      'consumes': {'قهوة مانجو': 17},
    },
    {
      'name': 'قهوة توت',
      'unit': 'cup',
      'sellPrice': 25.0,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
      'consumes': {'قهوة توت': 17},
    },
    {
      'name': 'قهوة فراولة',
      'unit': 'cup',
      'sellPrice': 25.0,
      'image': 'assets/drinks.jpg',
      'roastLevels': <String>[],
      'consumes': {'قهوة فراولة': 17},
    },
  ];

  // 3) حوِّل المنطقي إلى سكيمة نهائية بالـ IDs
  final batch = db.batch();
  for (final d in drinksLogical) {
    final name = d['name'] as String;
    final unit = d['unit'] ?? 'cup';
    final sellPrice = (d['sellPrice'] ?? 0).toDouble();
    final image = d['image'] ?? 'assets/drinks.jpg';
    final roastLevels = (d['roastLevels'] as List)
        .map((e) => e.toString())
        .toList();

    Map<String, num>? consumesById; // لمشروب بدون تحميص
    Map<String, Map<String, num>>? consumesByRoast; // لمشروب بتحميص

    double cupCost = 0; // اختياري—نحسبه للعرض السريع

    if (d.containsKey('perRoast')) {
      // مثال تركي: لكل Roast عندك map: اسم التوليفة -> grams
      consumesByRoast = {};
      (d['perRoast'] as Map<String, dynamic>).forEach((roast, baseMap) {
        final m = <String, num>{};
        (baseMap as Map<String, dynamic>).forEach((baseName, grams) {
          final blendId = idOf(baseName, roast);
          m[blendId] = (grams as num);
          cupCost += cpg(baseName, roast) * (grams as num);
        });
        consumesByRoast![roast] = m;
      });
    } else {
      // مفيش تحميص: map واحدة: اسم التوليفة -> grams
      consumesById = {};
      (d['consumes'] as Map<String, dynamic>).forEach((baseName, grams) {
        final blendId = idOf(baseName, '');
        consumesById![blendId] = (grams as num);
        cupCost += cpg(baseName, '') * (grams as num);
      });
    }

    final ref = db.collection('drinks').doc();
    batch.set(ref, {
      'name': name,
      'unit': unit,
      'sellPrice': sellPrice,
      'image': image,
      'roastLevels': roastLevels,
      // الحقول المهمة:
      if (consumesById != null) 'consumes': consumesById, // {blendDocId: grams}
      if (consumesByRoast != null)
        'consumesByRoast': consumesByRoast, // {roast: {blendDocId: grams}}
      // (اختياري) تكلفة الكوب المرجعية وقت الـ seed:
      'costPrice': double.parse(cupCost.toStringAsFixed(4)),
      'createdAt': DateTime.now().toUtc(),
    });
    print('✅ Drink added: $name');
  }

  await batch.commit();
  print("🎉 Done! Drinks seeded successfully.");
}
