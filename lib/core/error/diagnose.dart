import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> diagnoseInventory() async {
  final db = FirebaseFirestore.instance;
  debugPrint('🔎 بدء التشخيص...');

  final drinksSnap = await db.collection('drinks').get();
  debugPrint('📦 مشروبات: ${drinksSnap.docs.length}');

  int ok = 0, fail = 0;

  // هيلبر: شكله docId؟
  bool looksLikeId(String s) => RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(s);

  for (final d in drinksSnap.docs) {
    final data = d.data();
    final name = (data['name'] ?? '').toString();
    final roastLevels =
        (data['roastLevels'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];

    Map<String, num> consumes = {};
    String? roastKey;

    if (data['consumesByRoast'] is Map) {
      final m = Map<String, dynamic>.from(data['consumesByRoast']);
      roastKey = m.keys.first;
      consumes = Map<String, num>.from(m[roastKey] ?? {});
    } else if (data['consumes'] is Map) {
      consumes = Map<String, num>.from(data['consumes']);
    } else {
      debugPrint('❌ [$name] لا يحتوي consumes/consumesByRoast');
      fail++;
      continue;
    }

    debugPrint('— — — — —');
    debugPrint('🥤 $name ${roastKey != null ? "(roast=$roastKey)" : ""}');
    if (consumes.isEmpty) {
      debugPrint('❌ [$name] consumes فاضي');
      fail++;
      continue;
    }

    for (final entry in consumes.entries) {
      final key = entry.key.trim().replaceAll(RegExp(r'\s+'), ' ');
      final grams = entry.value;
      String? variantFromKey;

      // لو المفتاح “اسم + تحميص” استخرج التحميص
      if (roastLevels.isNotEmpty) {
        final parts = key.split(' ');
        if (parts.length >= 2 && roastLevels.contains(parts.last)) {
          variantFromKey = parts.last;
        }
      }

      final baseName = (variantFromKey != null)
          ? key.substring(0, key.length - variantFromKey.length).trim()
          : key;

      try {
        String? blendId;

        if (looksLikeId(key)) {
          blendId = key;
        } else {
          // Query بالاسم فقط
          final snap = await db
              .collection('blends')
              .where('name', isEqualTo: baseName)
              .limit(10)
              .get();

          if (snap.docs.isEmpty) {
            debugPrint('❌ [$name] لا يوجد blend بالاسم "$baseName"');
            fail++;
            continue;
          }

          // فلترة variant محليًا
          final effectiveVariant = (variantFromKey ?? roastKey ?? '').trim();
          QueryDocumentSnapshot<Map<String, dynamic>>? pick;
          if (effectiveVariant.isNotEmpty) {
            for (final doc in snap.docs) {
              final v = (doc.data()['variant'] ?? '').toString().trim();
              if (v == effectiveVariant) {
                pick = doc;
                break;
              }
            }
            pick ??= snap.docs.first;
          } else {
            pick = snap.docs.first;
          }
          blendId = pick.id;
        }

        // اتحقق من الحقول الرقمية
        final blendDoc = await db.collection('blends').doc(blendId).get();
        if (!blendDoc.exists) {
          debugPrint('❌ [$name] blendId غير موجود: $blendId');
          fail++;
          continue;
        }

        final b = blendDoc.data()!;
        final label = '${b['name'] ?? ''} ${b['variant'] ?? ''}'.trim();

        final stock = b['stock'];
        final costPrice = b['costPrice'];
        if (stock is! num) {
          debugPrint('❌ [$name][$label] stock نوعه مش Number: $stock');
          fail++;
        }
        if (costPrice is! num) {
          debugPrint('❌ [$name][$label] costPrice نوعه مش Number: $costPrice');
          fail++;
        }

        debugPrint('✅ [$name] يستهلك $grams g من [$label] (id=$blendId)');
        ok++;
      } catch (e, st) {
        debugPrint('💥 [$name][$baseName] خطأ: $e');
        debugPrint(st.toString());
        fail++;
      }
    }
  }

  debugPrint('— — — — —');
  debugPrint('✅ ناجحة: $ok | ❌ فاشلة: $fail');
  debugPrint('🔚 انتهى التشخيص.');
}
