part of 'blend_dialog.dart';

mixin _BlendDialogLoad on _BlendDialogStateBase {
  Future<void> _preloadVariantMeta() async {
    try {
      double numOf(dynamic v) =>
          (v is num) ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;
      bool? boolOf(Map<String, dynamic> map, String key) {
        if (!map.containsKey(key)) return null;
        final raw = map[key];
        if (raw is bool) return raw;
        if (raw is num) return raw != 0;
        final s = raw?.toString().trim().toLowerCase();
        if (s == 'true' || s == '1' || s == 'yes') return true;
        if (s == 'false' || s == '0' || s == 'no') return false;
        return null;
      }
      double numFrom(Map<String, dynamic> map, List<String> keys) {
        for (final key in keys) {
          if (map.containsKey(key)) return numOf(map[key]);
        }
        return 0.0;
      }
      final db = FirebaseFirestore.instance;
      final futures = <Future<void>>[];
      for (final v in widget.group.variants.values) {
        futures.add(
          db.collection('blends').doc(v.id).get().then((snap) {
            final m = snap.data();
            if (m == null) return;
            _spicesPricePerKgById[v.id] =
                numFrom(m, ['spicePricePerKg', 'spicesPrice']);
            _spicesCostPerKgById[v.id] =
                numFrom(m, ['spiceCostPerKg', 'spicesCost']);
            final spicedFlag = boolOf(m, 'spicedEnabled') ??
                boolOf(m, 'supportsSpice');
            _spicedEnabledById[v.id] = spicedFlag;
            _ginsengEnabledById[v.id] = boolOf(m, 'ginsengEnabled');
            _ginsengPricePerKgById[v.id] =
                numFrom(m, ['ginsengPricePerKg']);
            _ginsengCostPerKgById[v.id] =
                numFrom(m, ['ginsengCostPerKg']);
          }),
        );
      }
      await Future.wait(futures);
      if (mounted) setState(() {});
    } catch (_) {}
  }
}
