part of 'single_dialog.dart';

mixin _SingleDialogLoad on _SingleDialogStateBase {
  Future<void> _preloadStocks() async {
    try {
      final db = FirebaseFirestore.instance;
      final futures = <Future<void>>[];
      for (final v in widget.group.variants.values) {
        futures.add(
          db.collection('singles').doc(v.id).get().then((snap) {
            final m = snap.data();
            double stock = 0.0;
            double spicesPrice = 0.0;
            double spicesCost = 0.0;
            if (m != null) {
              final s = m['stock'];
              stock = (s is num) ? s.toDouble() : double.tryParse('$s') ?? 0.0;
              final spP = m['spicesPrice'];
              final spC = m['spicesCost'];
              spicesPrice = (spP is num)
                  ? spP.toDouble()
                  : double.tryParse('$spP') ?? 0.0;
              spicesCost = (spC is num)
                  ? spC.toDouble()
                  : double.tryParse('$spC') ?? 0.0;
            }
            _stockByVariantId[v.id] = stock;
            _spicesPriceByVariantId[v.id] = spicesPrice;
            _spicesCostByVariantId[v.id] = spicesCost;
          }),
        );
      }
      await Future.wait(futures);

      final sel = _selected;
      if (sel != null) {
        final st = _stockByVariantId[sel.id] ?? 0.0;
        if (st <= 0) {
          for (final opt in _roastOptions) {
            final v = widget.group.variants[opt];
            if (v == null) continue;
            final s = _stockByVariantId[v.id] ?? 0.0;
            if (s > 0) {
              _roast = opt;
              break;
            }
          }
        }
      }
    } catch (_) {
      // ?????
    } finally {
      if (mounted) setState(() => _stocksLoading = false);
    }
  }
}
