// lib/DrinkDialog.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:flutter/material.dart';

enum Serving { single, dbl }

class DrinkDialog extends StatefulWidget {
  final String drinkId;
  final Map<String, dynamic> drinkData;

  const DrinkDialog({
    super.key,
    required this.drinkId,
    required this.drinkData,
  });

  @override
  State<DrinkDialog> createState() => _DrinkDialogState();
}

class _DrinkDialogState extends State<DrinkDialog> {
  bool _busy = false;
  String? _fatal;
  int _qty = 1;

  // Roast
  late final List<String> _roastOptions;
  String? _roast;

  // Serving (سنجل/دوبل) للتركي/اسبريسو فقط
  Serving _serving = Serving.single;

  // Complimentary (ضيافة)
  bool _isComplimentary = false;

  // --------- getters آمنة ---------
  String get _name => (widget.drinkData['name'] ?? '').toString();

  String get _image =>
      (widget.drinkData['image'] ?? 'assets/drinks.jpg').toString();

  String get _unit => (widget.drinkData['unit'] ?? 'cup').toString();

  double get _sellPriceBase {
    final v = widget.drinkData['sellPrice'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  double get _costPriceSingle {
    final v = widget.drinkData['costPrice'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  double get _doubleCostPrice {
    final v = widget.drinkData['doubleCostPrice'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? (_costPriceSingle * 2.0);
  }

  double get _doubleDiscount {
    final v = widget.drinkData['doubleDiscount'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 10.0; // default 10
  }

  bool get _supportsServingChoice =>
      _name == 'قهوة تركي' || _name == 'قهوة اسبريسو';

  double get _unitPriceEffective {
    if (_isComplimentary) return 0.0;
    if (_supportsServingChoice && _serving == Serving.dbl) {
      return (_sellPriceBase * 2.0) - _doubleDiscount;
    }
    return _sellPriceBase;
  }

  double get _unitCostEffective {
    if (_supportsServingChoice && _serving == Serving.dbl) {
      return _doubleCostPrice;
    }
    return _costPriceSingle;
  }

  double get _totalPrice => _unitPriceEffective * _qty;
  double get _totalCost => _unitCostEffective * _qty;

  @override
  void initState() {
    super.initState();
    final rawLevels = widget.drinkData['roastLevels'];
    _roastOptions = (rawLevels is List)
        ? rawLevels
              .map((e) => (e ?? '').toString().trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
        : const <String>[];
    _roast = _roastOptions.isNotEmpty ? _roastOptions.first : null;
  }

  Future<void> _commitSale() async {
    if (_name.isEmpty) {
      setState(() => _fatal = 'اسم المنتج غير موجود.');
      await showErrorDialog(context, _fatal!);
      return;
    }

    setState(() {
      _busy = true;
      _fatal = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('sales').doc();

      await ref.set({
        'type': 'drink', // ← NEW: يحدد النوع بوضوح
        'created_at': DateTime.now().toUtc(),
        'created_by': 'cashier_web',

        'drink_id': widget.drinkId,
        'name': _name,
        'unit': _unit,
        'quantity': _qty, // ← CHANGED: نسجلها int مش double

        'roast': _roast ?? '',
        'serving': _supportsServingChoice
            ? (_serving == Serving.dbl ? 'double' : 'single')
            : 'single',
        'is_complimentary': _isComplimentary,

        // أسعار واضحة
        'list_price': _sellPriceBase,
        'unit_price': _unitPriceEffective,
        'total_price': _totalPrice,

        // تكاليف واضحة
        'list_cost': _costPriceSingle,
        'unit_cost': _unitCostEffective,
        'total_cost': _totalCost,

        // ربح
        'profit_total': _totalPrice - _totalCost,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تسجيل البيع')));
    } catch (e, st) {
      logError(e, st);
      if (!mounted) return;
      await showErrorDialog(context, e, st);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header image + title
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Stack(
                children: [
                  Image.asset(
                    _image,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.15),
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Text(
                        _name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Roast selector (لو موجود)
                  if (_roastOptions.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _roastOptions.map((r) {
                          final selected = (_roast ?? '') == r;
                          return ChoiceChip(
                            label: Text(r.isEmpty ? 'بدون' : r),
                            selected: selected,
                            onSelected: _busy
                                ? null
                                : (v) {
                                    if (!v) return;
                                    setState(() => _roast = r);
                                  },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // سنجل/دوبل للتركي/اسبريسو فقط
                  if (_supportsServingChoice) ...[
                    Align(
                      alignment: Alignment.center,
                      child: SegmentedButton<Serving>(
                        segments: const [
                          ButtonSegment(
                            value: Serving.single,
                            label: Text('سنجل'),
                            icon: Icon(Icons.coffee_outlined),
                          ),
                          ButtonSegment(
                            value: Serving.dbl,
                            label: Text('دوبل'),
                            icon: Icon(Icons.coffee),
                          ),
                        ],
                        selected: {_serving},
                        onSelectionChanged: _busy
                            ? null
                            : (s) => setState(() => _serving = s.first),
                        showSelectedIcon: false,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ضيافة
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.brown.shade50,
                      border: Border.all(color: Colors.brown.shade100),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      value: _isComplimentary,
                      onChanged: _busy
                          ? null
                          : (v) =>
                                setState(() => _isComplimentary = v ?? false),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('ضيافة'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // سعر الكوب الفعلي
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('سعر الكوب'),
                      Text('${_unitPriceEffective.toStringAsFixed(2)} جم'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Quantity stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        onPressed: _busy
                            ? null
                            : () {
                                if (_qty <= 1) return;
                                setState(() => _qty -= 1);
                              },
                        icon: const Icon(Icons.remove),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$_qty',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _qty += 1),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // إجمالي السعر
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.brown.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.brown.shade100),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الإجمالي',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(_totalPrice.toStringAsFixed(2)),
                      ],
                    ),
                  ),

                  if (_fatal != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _fatal!,
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _commitSale,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('تأكيد'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
