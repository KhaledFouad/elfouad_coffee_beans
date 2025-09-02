import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/blends_models.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:flutter/material.dart';

class BlendDialog extends StatefulWidget {
  final BlendGroup group;
  const BlendDialog({super.key, required this.group});

  @override
  State<BlendDialog> createState() => _BlendDialogState();
}

class _BlendDialogState extends State<BlendDialog> {
  bool _busy = false;
  String? _fatal;

  late final List<String> _variantOptions; // بدون الفارغ
  String? _variant; // null يعني مفيش درجات

  final TextEditingController _gramsCtrl = TextEditingController();
  int get _grams {
    final s = _gramsCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final v = int.tryParse(s) ?? 0;
    return v.clamp(0, 1000000);
  }

  bool _isComplimentary = false;

  @override
  void initState() {
    super.initState();

    // جهّز اختيارات التحميص: استبعد الفارغ ""
    _variantOptions =
        widget.group.variants.keys
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    // لو فيه درجات فعلاً: خُد أول واحدة. لو مفيش: سيبها null
    _variant = _variantOptions.isNotEmpty ? _variantOptions.first : null;
  }

  // اختَر الـ variant المختار؛ ولو مفيش درجات خالص، استخدم المفتاح الفارغ "" لو موجود
  BlendVariant? get _selected {
    if (_variant != null) {
      return widget.group.variants[_variant!];
    }
    // مفيش درجات: جرّب مفتاح فاضي "", أو لو فيه عنصر واحد خُده
    if (widget.group.variants.containsKey('')) {
      return widget.group.variants[''];
    }
    if (widget.group.variants.length == 1) {
      return widget.group.variants.values.first;
    }
    return null;
  }

  double get _sellPerKg => _selected?.sellPricePerKg ?? 0.0;
  double get _costPerKg => _selected?.costPricePerKg ?? 0.0;

  double get _sellPerG => _sellPerKg / 1000.0;
  double get _costPerG => _costPerKg / 1000.0;

  double get _pricePerG => _isComplimentary ? 0.0 : _sellPerG;

  double get _totalPrice => _pricePerG * _grams;
  double get _totalCost => _costPerG * _grams;

  Future<void> _commitSale() async {
    final sel = _selected;
    if (sel == null) {
      setState(() => _fatal = 'لم يتم تحديد الصنف/التحميص.');
      await showErrorDialog(context, _fatal!);
      return;
    }
    if (_grams <= 0) {
      setState(() => _fatal = 'من فضلك أدخل كمية صحيحة بالجرام.');
      await showErrorDialog(context, _fatal!);
      return;
    }

    setState(() {
      _busy = true;
      _fatal = null;
    });

    final db = FirebaseFirestore.instance;
    final itemRef = db.collection('blends').doc(sel.id);

    try {
      await db.runTransaction((txn) async {
        final snap = await txn.get(itemRef);
        if (!snap.exists) throw Exception('التوليفة غير موجودة بالمخزون.');

        final data = snap.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] is num)
            ? (data['stock'] as num).toDouble()
            : double.tryParse((data['stock'] ?? '0').toString()) ?? 0.0;

        if (currentStock < _grams) {
          throw Exception(
            'المخزون غير كافٍ. المتاح: ${currentStock.toStringAsFixed(0)} جم',
          );
        }

        final newStock = currentStock - _grams;
        txn.update(itemRef, {'stock': newStock});

        final saleRef = db.collection('sales').doc();
        txn.set(saleRef, {
          'created_at': DateTime.now().toUtc(),
          'created_by': 'cashier_web',
          'type': 'ready_blend',
          'item_id': sel.id,
          'name': sel.name,
          'variant': sel.variant, // ممكن تبقى "" لو مفيش تحميص
          'unit': 'g',
          'grams': _grams.toDouble(),
          'is_complimentary': _isComplimentary,

          'price_per_kg': _sellPerKg,
          'price_per_g': _pricePerG, // 0 لو ضيافة
          'total_price': _totalPrice,

          'cost_per_kg': _costPerKg,
          'cost_per_g': _costPerG,
          'total_cost': _totalCost,

          'profit_total': _totalPrice - _totalCost,
          'stock_after': newStock,
        });
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل بيع التوليفة وخصم المخزون')),
      );
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
    final name = widget.group.name;
    final image = widget.group.image;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Stack(
                children: [
                  Image.asset(
                    image,
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
                        name,
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

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // لو فيه درجات فعلًا، اعرضها؛ غير كده، ولا حاجة
                  if (_variantOptions.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _variantOptions.map((r) {
                          final selected = (_variant ?? '') == r;
                          return ChoiceChip(
                            label: Text(r),
                            selected: selected,
                            onSelected: _busy
                                ? null
                                : (v) {
                                    if (!v) return;
                                    setState(() => _variant = r);
                                  },
                          );
                        }).toList(),
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
                      title: const Text(
                        'ضيافة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // إدخال الكمية بالجرامات
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      children: [
                        const Text('الكمية (جم)'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _gramsCtrl,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}), // تحديث الإجمالي
                            decoration: const InputDecoration(
                              hintText: 'مثال: 250',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 10,
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  _KVRow(k: 'سعر/كجم', v: _sellPerKg, suffix: 'جم'),
                  _KVRow(k: 'سعر/جرام', v: _pricePerG, suffix: 'جم'),
                  const SizedBox(height: 8),

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

  @override
  void dispose() {
    _gramsCtrl.dispose();
    super.dispose();
  }
}

class _KVRow extends StatelessWidget {
  final String k;
  final double v;
  final String? suffix;
  const _KVRow({super.key, required this.k, required this.v, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(k),
        const Spacer(),
        Text('${v.toStringAsFixed(2)}${suffix != null ? ' $suffix' : ''}'),
      ],
    );
  }
}
