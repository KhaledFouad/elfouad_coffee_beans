import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/blends_models.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:flutter/material.dart';

class UserFriendly implements Exception {
  final String message;
  UserFriendly(this.message);
  @override
  String toString() => message;
}

class BlendDialog extends StatefulWidget {
  final BlendGroup group;
  const BlendDialog({super.key, required this.group});

  @override
  State<BlendDialog> createState() => _BlendDialogState();
}

class _BlendDialogState extends State<BlendDialog> {
  bool _busy = false;
  String? _fatal;

  // هل يُسمح بالتحويج لهذا الصنف؟
  bool get _canSpice {
    final sel = _selected;
    if (sel == null) return false;
    final nm = sel.name.trim();
    if (nm == 'توليفة فرنساوي') return false;
    if (_flavored.contains(nm)) return false;
    return true;
  }

  late final List<String> _variantOptions; // بدون الفارغ
  String? _variant; // null يعني مفيش درجات

  final TextEditingController _gramsCtrl = TextEditingController();
  int get _grams {
    final s = _gramsCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final v = int.tryParse(s) ?? 0;
    return v.clamp(0, 1000000);
  }

  bool _isComplimentary = false;
  bool _isSpiced = false; // محوّج

  // نكهات مستثناة من التحويج + فرنساوي
  static const Set<String> _flavored = {
    'قهوة كراميل',
    'قهوة بندق',
    'قهوة بندق قطع',
    'قهوة شوكلت',
    'قهوة فانيليا',
    'قهوة توت',
    'قهوة فراولة',
    'قهوة مانجو',
  };

  @override
  void initState() {
    super.initState();
    _variantOptions =
        widget.group.variants.keys
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    _variant = _variantOptions.isNotEmpty ? _variantOptions.first : null;
  }

  BlendVariant? get _selected {
    if (_variant != null) return widget.group.variants[_variant!];
    if (widget.group.variants.containsKey('')) return widget.group.variants[''];
    if (widget.group.variants.length == 1)
      return widget.group.variants.values.first;
    return null;
  }

  double get _sellPerKg => _selected?.sellPricePerKg ?? 0.0;
  double get _costPerKg => _selected?.costPricePerKg ?? 0.0;

  double get _sellPerG => _sellPerKg / 1000.0;
  double get _costPerG => _costPerKg / 1000.0;

  double get _beansAmount => _sellPerG * _grams;

  // 40/كجم للتوليفات الجاهزة (عدا فرنساوي + النكهات)
  double get _spiceRatePerKg {
    final sel = _selected;
    if (!_isSpiced || sel == null) return 0.0;
    final nm = sel.name.trim();
    if (nm == 'توليفة فرنساوي') return 0.0;
    if (_flavored.contains(nm)) return 0.0;
    return 40.0;
  }

  double get _spiceAmount =>
      _isSpiced ? (_grams / 1000.0) * _spiceRatePerKg : 0.0;

  double get _pricePerG => _isComplimentary ? 0.0 : _sellPerG; // للعرض فقط
  double get _totalPrice =>
      _isComplimentary ? 0.0 : (_beansAmount + _spiceAmount);
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
        if (!snap.exists) throw UserFriendly('التوليفة غير موجودة بالمخزون.');

        final data = snap.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] is num)
            ? (data['stock'] as num).toDouble()
            : double.tryParse((data['stock'] ?? '0').toString()) ?? 0.0;

        final need = _grams.toDouble();
        if (currentStock < need) {
          final avail = currentStock.toStringAsFixed(0);
          final want = need.toStringAsFixed(0);
          throw UserFriendly(
            'المخزون غير كافٍ.\nالمتاح: $avail جم • المطلوب: $want جم',
          );
        }

        final newStock = currentStock - need;
        txn.update(itemRef, {'stock': newStock});

        final saleRef = db.collection('sales').doc();
        txn.set(saleRef, {
          'created_at': DateTime.now().toUtc(),
          'created_by': 'cashier_web',
          'type': 'ready_blend',
          'item_id': sel.id,
          'name': sel.name,
          'variant': sel.variant,
          'unit': 'g',
          'grams': need,
          'is_complimentary': _isComplimentary,

          // بن
          'price_per_kg': _sellPerKg,
          'price_per_g': _pricePerG,
          'beans_amount': _beansAmount,

          // تحويج
          'is_spiced': _isSpiced,
          'spice_rate_per_kg': _spiceRatePerKg,
          'spice_amount': _spiceAmount,

          // إجمالي
          'total_price': _totalPrice,

          // تكاليف
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
      final msg = e is UserFriendly
          ? e.message
          : (e is FirebaseException
                ? 'خطأ في قاعدة البيانات (${e.code})'
                : 'حدث خطأ غير متوقع.');
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تعذر إتمام العملية'),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
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
                                    setState(() {
                                      _variant = r;
                                      if (!_canSpice)
                                        _isSpiced =
                                            false; // إلغاء التحويج لو غير مسموح
                                    });
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
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_canSpice)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.brown.shade50,
                        border: Border.all(color: Colors.brown.shade100),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CheckboxListTile(
                        value: _isSpiced,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _isSpiced = v ?? false),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'محوّج',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

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
                            onChanged: (_) => setState(() {}),
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
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _totalPrice.toStringAsFixed(2),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_fatal != null) ...[
                    const SizedBox(height: 10),
                    _WarningBox(text: _fatal!),
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
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
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
                          : const Text(
                              'تأكيد',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
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
  const _KVRow({required this.k, required this.v, this.suffix});

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

class _WarningBox extends StatelessWidget {
  final String text;
  const _WarningBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Text(text, style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
}
