int drinkPriority(String name) {
  return _priorityForGroups(name, _drinkPriorityGroups);
}

int blendPriority(String name) {
  return _priorityForGroups(name, _blendPriorityGroups);
}

void sortByPriorityThenName<T>(
  List<T> items, {
  required int Function(T item) priority,
  required String Function(T item) name,
  String Function(T item)? tieBreaker,
}) {
  items.sort((a, b) {
    final pa = priority(a);
    final pb = priority(b);
    if (pa != pb) return pa.compareTo(pb);

    final na = name(a).toLowerCase();
    final nb = name(b).toLowerCase();
    final nameCmp = na.compareTo(nb);
    if (nameCmp != 0) return nameCmp;

    if (tieBreaker == null) return 0;
    return tieBreaker(a).compareTo(tieBreaker(b));
  });
}

int _priorityForGroups(String rawName, List<List<String>> groups) {
  final normalized = rawName.toLowerCase();
  for (var i = 0; i < groups.length; i++) {
    if (_containsAny(normalized, groups[i])) return i;
  }
  return groups.length;
}

bool _containsAny(String value, List<String> keywords) {
  for (final keyword in keywords) {
    if (value.contains(keyword)) return true;
  }
  return false;
}

const List<List<String>> _drinkPriorityGroups = [
  ['تركي', 'turk'],
  ['اسبريسو', 'espresso'],
  ['فرنساوي', 'فرنسي', 'french'],
  ['بندق', 'hazelnut'],
  ['شاي', 'tea', 'مياه', 'water'],
  ['كوفي ميكس', 'coffee mix', '3in1', '3 in 1'],
  ['نسكافيه', 'nescafe'],
  ['هوت شوكلت', 'hot chocolate', 'كاكاو', 'cocoa'],
];

const List<List<String>> _blendPriorityGroups = [
  ['كلاسيك', 'classic'],
  ['مخصوص'],
  ['اسبيشيال', 'special'],
  ['القهاوي', 'القهاوى', 'qahawy', 'qahawi'],
  ['بندق', 'hazelnut'],
  ['الفؤاد', 'fouad'],
];
