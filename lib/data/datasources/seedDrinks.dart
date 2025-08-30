import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedDrinks() async {
  print("🚀 Seeding started for drinks...");

  final firestore = FirebaseFirestore.instance;
  final drinks = firestore.collection('drinks');
  final products = firestore.collection('blends'); // خليه من blends مش products
  final batch = firestore.batch();

  try {
    Future<num> getCostPerGram(String name, [String? variant]) async {
      Query query = products.where('name', isEqualTo: name);
      if (variant != null && variant.trim().isNotEmpty) {
        query = query.where('variant', isEqualTo: variant);
      }
      final snap = await query.limit(1).get();
      if (snap.docs.isEmpty) {
        throw Exception("❌ المنتج $name ${variant ?? ''} مش موجود في blends");
      }
      final data = snap.docs.first.data() as Map<String, dynamic>;
      return (data['costPrice'] as num) / 1000;
    }

    // جيب أسعار البن
    final turkishLight = await getCostPerGram("توليفة اسبيشيال", "فاتح");
    final turkishMedium = await getCostPerGram("توليفة اسبيشيال", "وسط");
    final turkishDark = await getCostPerGram("توليفة اسبيشيال", "غامق");
    final espresso = await getCostPerGram("توليفة اسبريسو");
    final frenchCoffee = await getCostPerGram("توليفة فرنساوي");
    final chocolateCoffee = await getCostPerGram("قهوة شوكلت");
    final vanillaCoffee = await getCostPerGram("قهوة فانيليا");
    final hazelnutCoffee = await getCostPerGram("قهوة بندق");
    final hazelnutPiecesCoffee = await getCostPerGram("قهوة بندق قطع");
    final caramelCoffee = await getCostPerGram("قهوة كراميل");
    final mangoCoffee = await getCostPerGram("قهوة مانجو");
    final berryCoffee = await getCostPerGram("قهوة توت");
    final strawberryCoffee = await getCostPerGram("قهوة فراولة");

    final allDrinks = [
      {
        "name": "قهوة تركي",
        "variant": "فاتح",
        "category": "مشروبات",
        "unit": "cup",
        "sellPrice": 15,
        "costPrice": turkishLight * 10,
        "consumes": {"توليفة اسبيشيال فاتح": 10},
      },
      {
        "name": "قهوة تركي",
        "variant": "وسط",
        "category": "مشروبات",
        "unit": "cup",
        "sellPrice": 15,
        "costPrice": turkishMedium * 10,
        "consumes": {"توليفة اسبيشيال وسط": 10},
      },
      {
        "name": "قهوة تركي",
        "variant": "غامق",
        "category": "مشروبات",
        "unit": "cup",
        "sellPrice": 15,
        "costPrice": turkishDark * 10,
        "consumes": {"توليفة اسبيشيال غامق": 10},
      },

      {
        "name": "قهوة اسبريسو",
        "variant": "",
        "category": "مشروبات",
        "unit": "cup",
        "sellPrice": 20,
        "costPrice": espresso * 8,
        "consumes": {"توليفة اسبريسو": 8},
      },

      {
        "name": "قهوة بندق",
        "variant": "",
        "category": "مشروبات",
        "unit": "cup",
        "sellPrice": 25,
        "costPrice": hazelnutCoffee * 20,
        "consumes": {"قهوة بندق": 20},
      },

      {
        "name": "قهوة بندق قطع",
        "variant": "",
        "category": "مشروبات",
        "unit": "cup",
        "sellPrice": 25,
        "costPrice": hazelnutPiecesCoffee * 20,
        "consumes": {"قهوة بندق قطع": 20},
      },
      {
        "name": "قهوة فرنساوي",
        "variant": "",
        "category": "مشروبات",
        "unit": "cup",
        "sellPrice": 25,
        "costPrice": frenchCoffee * 15,
        "consumes": {"توليفة فرنساوي": 15},
      },
      {
        "name": "قهوة شوكلت",
        "variant": "",
        "category": "مشروبات",
        "unit": "cup",
        "sellPrice": 25,
        "costPrice": chocolateCoffee * 20,
        "consumes": {"قهوة شوكلت": 20},
      },
      {
        "name": "قهوة كراميل",
        "variant": "",
        "category": "مشروبات",
        "unit": "cup",
        "sellPrice": 25,
        "costPrice": caramelCoffee * 20,
        "consumes": {"قهوة كراميل": 20},
      },
      {
        "name": "قهوة فانيليا",
        "variant": "",
        "category": "مشروبات",
        "unit": "cup",
        "sellPrice": 25,
        "costPrice": vanillaCoffee * 20,
        "consumes": {"قهوة فانيليا": 20},
      },

      {
        "name": "قهوة مانجو",
        "variant": "",
        "category": "مشروبات",
        "unit": "cup",
        "sellPrice": 25,
        "costPrice": mangoCoffee * 17,
        "consumes": {"قهوة مانجو": 17},
      },
      {
        "name": "قهوة توت",
        "variant": "",
        "category": "مشروبات",
        "unit": "cup",
        "sellPrice": 25,
        "costPrice": berryCoffee * 17,
        "consumes": {"قهوة توت": 17},
      },
      {
        "name": "قهوة فراولة",
        "variant": "",
        "category": "مشروبات",
        "unit": "cup",
        "sellPrice": 25,
        "costPrice": strawberryCoffee * 17,
        "consumes": {"قهوة فراولة": 17},
      },
    ];

    for (var d in allDrinks) {
      final doc = drinks.doc();
      batch.set(doc, d);
    }

    await batch.commit();
    print("🎉 Done! Seeded ${allDrinks.length} drinks successfully.");
  } catch (e) {
    print("❌ Error while seeding drinks: $e");
  }
}
