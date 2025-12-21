part of 'blend_dialog.dart';

mixin _BlendDialogLoad on _BlendDialogStateBase {
  Future<void> _preloadVariantMeta() async {
    try {
      final db = FirebaseFirestore.instance;
      final futures = <Future<void>>[];
      for (final v in widget.group.variants.values) {
        futures.add(
          db.collection('blends').doc(v.id).get().then((snap) {
            final m = snap.data();
            if (m == null) return;
            _spicesPricePerKgById[v.id] = (m['spicesPrice'] is num)
                ? (m['spicesPrice'] as num).toDouble()
                : double.tryParse('${m['spicesPrice'] ?? ''}') ?? 0.0;
            _spicesCostPerKgById[v.id] = (m['spicesCost'] is num)
                ? (m['spicesCost'] as num).toDouble()
                : double.tryParse('${m['spicesCost'] ?? ''}') ?? 0.0;
            _supportsSpiceById[v.id] = (m['supportsSpice'] == true);
          }),
        );
      }
      await Future.wait(futures);
      if (mounted) setState(() {});
    } catch (_) {}
  }
}
