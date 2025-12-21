part of 'custom_blends_page.dart';

mixin _CustomBlendsLoad on _CustomBlendsStateBase {
  Map<String, dynamic>? _initialBlendData;

  /// تحميل العناصر المنفردة + بعض التوليفات الجاهزة بأسمائها المحددة
  Future<void> _loadItems() async {
    try {
      final db = FirebaseFirestore.instance;

      // singles
      final singlesSnap = await db.collection('singles').orderBy('name').get();
      final singles = singlesSnap.docs
          .map(SingleVariantItem.fromSinglesDoc)
          .toList();

      // blends (محددة بالأسماء + كل درجات التحميص)
      const allowedBlendNames = {
        'توليفة كلاسيك',
        'توليفة مخصوص',
        'توليفة اسبيشيال',
        'توليفة الفؤاد',
        'توليفة القهاوى',
      };

      final blendsSnap = await db
          .collection('blends')
          .where('name', whereIn: allowedBlendNames.toList())
          .get();
      final blends = blendsSnap.docs
          .map(SingleVariantItem.fromBlendsDoc)
          .toList();

      final all = <SingleVariantItem>[...singles, ...blends];

      // ترتيب: المتاح أولاً
      all.sort((a, b) {
        final az = a.stock <= 0 ? 1 : 0;
        final bz = b.stock <= 0 ? 1 : 0;
        if (az != bz) return az.compareTo(bz);
        return a.fullLabel.compareTo(b.fullLabel);
      });

      if (_initialBlendData == null && widget.initialBlend != null) {
        _initialBlendData = await _hydrateInitialBlend(
          db,
          widget.initialBlend!,
        );
      }

      if (!mounted) return;
      setState(() {
        _allItems = all;
      });
      _applyInitialBlendIfPossible();
    } catch (e) {
      setState(() => _fatal = 'تعذر تحميل الأصناف.');
    }
  }

  double _readDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  int _readInt(dynamic v) {
    if (v is int) return v < 0 ? 0 : v;
    if (v is num) return v.round().clamp(0, 1000000);
    final parsed = int.tryParse(v?.toString() ?? '');
    if (parsed == null) return 0;
    return parsed < 0 ? 0 : parsed;
  }

  bool _readBool(dynamic v) => v == true;

  List<dynamic> _coerceComponentsList(dynamic components) {
    if (components is List) return components;
    if (components is Map) return components.values.toList();
    return const [];
  }

  Future<Map<String, dynamic>> _hydrateInitialBlend(
    FirebaseFirestore db,
    Map<String, dynamic> raw,
  ) async {
    final components = _coerceComponentsList(raw['components']);
    if (components.isNotEmpty) {
      return raw;
    }

    final saleId = (raw['sale_id'] ?? raw['invoice_id'] ?? '')
        .toString()
        .trim();
    if (saleId.isEmpty) {
      return raw;
    }

    try {
      final snap = await db.collection('sales').doc(saleId).get();
      if (!snap.exists) return raw;
      final data = snap.data();
      if (data == null) return raw;
      final fallback = _extractComponentsFromSale(data, raw);
      if (fallback == null || fallback.isEmpty) return raw;
      return {...raw, 'components': fallback};
    } catch (_) {
      return raw;
    }
  }

  List<dynamic>? _extractComponentsFromSale(
    Map<String, dynamic> sale,
    Map<String, dynamic> blend,
  ) {
    final direct = _coerceComponentsList(sale['components']);
    if (direct.isNotEmpty) return direct;

    final meta = sale['meta'];
    if (meta is Map) {
      final metaComponents = _coerceComponentsList(meta['components']);
      if (metaComponents.isNotEmpty) return metaComponents;
    }

    final items = sale['items'];
    if (items is List) {
      final title = (blend['title'] ?? blend['custom_title'] ?? '')
          .toString()
          .trim();
      for (final raw in items) {
        if (raw is! Map) continue;
        final type = (raw['type'] ?? '').toString();
        if (type != 'custom_blend') continue;
        final rawMeta = raw['meta'];
        final metaMap = rawMeta is Map ? rawMeta : const <String, dynamic>{};
        final itemTitle =
            (metaMap['custom_title'] ?? raw['variant'] ?? raw['name'] ?? '')
                .toString()
                .trim();
        if (title.isNotEmpty && itemTitle != title) continue;
        final comp = _coerceComponentsList(
          metaMap['components'] ?? raw['components'],
        );
        if (comp.isNotEmpty) return comp;
      }
      if (title.isEmpty) {
        for (final raw in items) {
          if (raw is! Map) continue;
          if ((raw['type'] ?? '').toString() != 'custom_blend') continue;
          final rawMeta = raw['meta'];
          final metaMap = rawMeta is Map ? rawMeta : const <String, dynamic>{};
          final comp = _coerceComponentsList(
            metaMap['components'] ?? raw['components'],
          );
          if (comp.isNotEmpty) return comp;
        }
      }
    }

    return null;
  }

  Future<DocumentReference<Map<String, dynamic>>> _resolveCustomBlendRef(
    FirebaseFirestore db,
    String title,
  ) async {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      return db.collection('custom_blends').doc();
    }
    final snap = await db
        .collection('custom_blends')
        .where('title', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.first.reference;
    }
    return db.collection('custom_blends').doc();
  }

  SingleVariantItem? _findItem(String id, ItemSource source) {
    for (final it in _allItems) {
      if (it.id == id && it.source == source) return it;
    }
    return null;
  }

  SingleVariantItem? _findItemByLabel(
    String name,
    String variant,
    ItemSource source,
  ) {
    final nameNorm = name.trim();
    final variantNorm = variant.trim();
    for (final it in _allItems) {
      if (it.source != source) continue;
      if (it.name.trim() != nameNorm) continue;
      if (it.variant.trim() != variantNorm) continue;
      return it;
    }
    if (variantNorm.isEmpty) {
      for (final it in _allItems) {
        if (it.source != source) continue;
        if (it.name.trim() == nameNorm) return it;
      }
    }
    return null;
  }

  SingleVariantItem? _findItemByLabelAnySource(String name, String variant) {
    final nameNorm = name.trim();
    final variantNorm = variant.trim();
    if (nameNorm.isEmpty) return null;
    for (final it in _allItems) {
      if (it.name.trim() != nameNorm) continue;
      if (it.variant.trim() != variantNorm) continue;
      return it;
    }
    if (variantNorm.isEmpty) {
      for (final it in _allItems) {
        if (it.name.trim() == nameNorm) return it;
      }
    }
    return null;
  }

  SingleVariantItem? _findItemByIdAnySource(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    for (final it in _allItems) {
      if (it.id == trimmed) return it;
    }
    if (trimmed.contains('/')) {
      final tail = trimmed.split('/').last;
      for (final it in _allItems) {
        if (it.id == tail) return it;
      }
    }
    return null;
  }

  ItemSource? _parseItemSource(dynamic raw) {
    if (raw is ItemSource) return raw;
    if (raw is int) {
      if (raw == ItemSource.singles.index) return ItemSource.singles;
      if (raw == ItemSource.blends.index) return ItemSource.blends;
    }
    final normalized = raw?.toString().trim().toLowerCase() ?? '';
    if (normalized == 'singles' || normalized == 'single') {
      return ItemSource.singles;
    }
    if (normalized == 'blends' || normalized == 'blend') {
      return ItemSource.blends;
    }
    return null;
  }

  bool _deriveSpicedFromComponents(dynamic components) {
    final list = _coerceComponentsList(components);
    if (list.isEmpty) return false;
    for (final raw in list) {
      if (raw is! Map) continue;
      final rate = _readDouble(raw['spice_rate_per_kg']);
      final cost = _readDouble(raw['spice_cost_per_kg']);
      if (rate > 0 || cost > 0) return true;
    }
    return false;
  }

  void _applyInitialBlendIfPossible() {
    final data = _initialBlendData ?? widget.initialBlend;
    if (_templateApplied || data == null || _allItems.isEmpty) {
      return;
    }
    final components = _coerceComponentsList(data['components']);

    final newLines = <_BlendLine>[];
    if (components.isNotEmpty) {
      for (final raw in components) {
        if (raw is! Map) continue;
        final source = _parseItemSource(raw['source']);
        final rawId =
            raw['item_id'] ?? raw['itemId'] ?? raw['id'] ?? raw['product_id'];
        String id;
        if (rawId is DocumentReference) {
          id = rawId.id;
        } else {
          id = rawId?.toString().trim() ?? '';
        }
        SingleVariantItem? item;
        if (id.isNotEmpty && source != null) {
          item = _findItem(id, source);
        }
        if (item == null && id.isNotEmpty) {
          item = _findItemByIdAnySource(id);
        }
        if (item == null) {
          final name = (raw['name'] ?? '').toString();
          final variant = (raw['variant'] ?? '').toString();
          if (source != null) {
            item = _findItemByLabel(name, variant, source);
          }
          item ??= _findItemByLabelAnySource(name, variant);
        }
        if (item == null) continue;
        final grams = _readInt(raw['grams']);
        if (grams <= 0) continue;
        final line = _BlendLine()
          ..item = item
          ..mode = LineInputMode.grams
          ..grams = grams;
        newLines.add(line);
      }
    }

    final title = (data['title'] ?? data['custom_title'] ?? '')
        .toString()
        .trim();
    final isComplimentary = _readBool(data['is_complimentary']);
    final isDeferred = _readBool(data['is_deferred']);
    final isSpiced =
        _readBool(data['spiced']) || _deriveSpicedFromComponents(components);
    final ginsengGrams = _readInt(data['ginseng_grams']);
    final canSpice = newLines.any((l) => l.item?.supportsSpice == true);

    if (newLines.isEmpty) newLines.add(_BlendLine());

    setState(() {
      _lines
        ..clear()
        ..addAll(newLines);
      if (title.isNotEmpty) {
        _titleCtrl.text = title;
      }
      _isComplimentary = isComplimentary;
      _isDeferred = isComplimentary ? false : isDeferred;
      _isSpiced = isSpiced && canSpice;
      _ginsengGrams = ginsengGrams;
      if (_isComplimentary) {
        _noteCtrl.clear();
      }
      _templateApplied = true;
    });
  }
}
