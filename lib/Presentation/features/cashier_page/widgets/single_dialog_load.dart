part of 'single_dialog.dart';

mixin _SingleDialogLoad on _SingleDialogStateBase {
  Future<void> _preloadStocks() async {
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
          db.collection('singles').doc(v.id).get().then((snap) {
            final m = snap.data();
            double stock = 0.0;
            double spicesPrice = 0.0;
            double spicesCost = 0.0;
            double ginsengPrice = 0.0;
            double ginsengCost = 0.0;
            bool? spicedEnabled;
            bool? ginsengEnabled;
            if (m != null) {
              stock = numOf(m['stock']);
              spicesPrice =
                  numFrom(m, ['spicePricePerKg', 'spicesPrice']);
              spicesCost = numFrom(m, ['spiceCostPerKg', 'spicesCost']);
              ginsengPrice = numFrom(m, ['ginsengPricePerKg']);
              ginsengCost = numFrom(m, ['ginsengCostPerKg']);
              spicedEnabled = boolOf(m, 'spicedEnabled');
              ginsengEnabled = boolOf(m, 'ginsengEnabled');
            }
            _stockByVariantId[v.id] = stock;
            _spicesPriceByVariantId[v.id] = spicesPrice;
            _spicesCostByVariantId[v.id] = spicesCost;
            _spicedEnabledByVariantId[v.id] = spicedEnabled;
            _ginsengEnabledByVariantId[v.id] = ginsengEnabled;
            _ginsengPricePerKgByVariantId[v.id] = ginsengPrice;
            _ginsengCostPerKgByVariantId[v.id] = ginsengCost;
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
