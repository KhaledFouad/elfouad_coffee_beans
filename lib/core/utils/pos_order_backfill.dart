import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

typedef PosOrderLog = void Function(String message);

const int _defaultPosOrder = 999999;
const int _batchLimit = 450;

class _PosOrderRule {
  final int posOrder;
  final List<String> keywords;
  const _PosOrderRule(this.posOrder, this.keywords);
}

const List<_PosOrderRule> _drinkRules = [
  _PosOrderRule(10, ['تركي', 'turk']),
  _PosOrderRule(20, ['اسبريسو', 'espresso']),
  _PosOrderRule(30, ['فرنساوي', 'فرنسي', 'french']),
  _PosOrderRule(40, ['بندق', 'hazelnut']),
  _PosOrderRule(50, ['شاي', 'tea', 'مياه', 'water']),
  _PosOrderRule(60, ['كوفي ميكس', 'coffee mix', '3in1', '3 in 1']),
  _PosOrderRule(70, ['نسكافيه', 'nescafe']),
  _PosOrderRule(80, ['هوت شوكلت', 'hot chocolate', 'كاكاو', 'cocoa']),
];

const List<_PosOrderRule> _blendRules = [
  _PosOrderRule(10, ['كلاسيك', 'classic']),
  _PosOrderRule(20, ['مخصوص']),
  _PosOrderRule(30, ['اسبيشيال', 'special']),
  _PosOrderRule(40, ['القهاوي', 'القهاوى', 'qahawy', 'qahawi']),
  _PosOrderRule(50, ['بندق', 'hazelnut']),
  _PosOrderRule(60, ['الفؤاد', 'fouad']),
];

int _matchPosOrder(String name, List<_PosOrderRule> rules) {
  final normalized = name.toLowerCase();
  for (final rule in rules) {
    for (final keyword in rule.keywords) {
      if (normalized.contains(keyword)) return rule.posOrder;
    }
  }
  return _defaultPosOrder;
}

void _log(PosOrderLog? log, String message) {
  if (log != null) {
    log(message);
    return;
  }
  debugPrint(message);
}

Future<int> _backfillCollection({
  required FirebaseFirestore db,
  required String collection,
  required List<_PosOrderRule> rules,
  PosOrderLog? log,
}) async {
  final snap = await db.collection(collection).get();
  var updated = 0;
  var batchCount = 0;
  var batch = db.batch();

  for (final doc in snap.docs) {
    final data = doc.data();
    if (data.containsKey('posOrder') && data['posOrder'] != null) continue;

    final name = (data['name'] ?? '').toString();
    final posOrder = _matchPosOrder(name, rules);
    batch.update(doc.reference, {'posOrder': posOrder});
    updated += 1;
    batchCount += 1;

    if (batchCount >= _batchLimit) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  _log(log, 'posOrder backfill: $collection updated $updated docs');
  return updated;
}

/// Manual backfill for posOrder on drinks & blends.
/// Call this from a debug-only path or a temporary main() hook.
Future<void> backfillPosOrder({
  FirebaseFirestore? firestore,
  PosOrderLog? log,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final drinksUpdated = await _backfillCollection(
    db: db,
    collection: 'drinks',
    rules: _drinkRules,
    log: log,
  );
  final blendsUpdated = await _backfillCollection(
    db: db,
    collection: 'blends',
    rules: _blendRules,
    log: log,
  );
  _log(
    log,
    'posOrder backfill complete. drinks=$drinksUpdated, blends=$blendsUpdated',
  );
}
