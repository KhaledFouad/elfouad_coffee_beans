// lib/Presentation/features/cashier_page/widgets/DrinkDialog.dart
// ignore_for_file: unused_local_variable, unused_element

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/deferred_note_field.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:flutter/material.dart';
import 'toggle_card.dart'; // الكارد المعاد استخدامه

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
  bool _isDeferred = false; // أجّل
  bool _busy = false;
  String? _fatal;
  int _qty = 1;
  final TextEditingController _noteCtrl = TextEditingController();

  // Serving (سنجل/دوبل) للتركي/اسبريسو فقط
  Serving _serving = Serving.single;

  // Complimentary (ضيافة)
  bool _isComplimentary = false;

  // Coffee Mix (مياه/لبن)
  bool get _isCoffeeMix => _name.trim() == 'كوفي ميكس';
  String _mix = 'water'; // water | milk

  // --------- Utilities ---------
  String _norm(String s) => s.replaceAll('ى', 'ي').trim();
  bool _isNum(dynamic v) =>
      v is num || double.tryParse(v?.toString() ?? '') != null;
  double _numOf(dynamic v, [double def = 0.0]) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? def;
  }

  // --------- getters آمنة ---------
  String get _name => (widget.drinkData['name'] ?? '').toString();
  String get _image =>
      (widget.drinkData['image'] ?? 'assets/drinks.jpg').toString();
  String get _unit => (widget.drinkData['unit'] ?? 'cup').toString();

  double get _sellPriceBase => _numOf(widget.drinkData['sellPrice']);

  // ==== Spice option (Turkish only) ====
  bool _spiced = false;

  bool get _isTurkish {
    final n = _norm(_name);
    return n == _norm('قهوة تركي');
  }

  // ==== دوال تساعد على تنافي "ضيافة" و"أجِّل" ====
  void _setComplimentary(bool v) {
    setState(() {
      _isComplimentary = v;
      if (v) {
        _isDeferred = false; // تنافي
        _noteCtrl.clear();
      }
    });
  }

  void _setDeferred(bool v) {
    setState(() {
      _isDeferred = v;
      if (v) {
        _isComplimentary = false; // تنافي
      } else {
        _noteCtrl.clear();
      }
    });
  }

  double get _spicedCupCost =>
      _numOf(widget.drinkData['spicedCupCost'], _costPriceSingle);

  // تكلفة سنجل أساسية
  double get _costPriceSingle => _numOf(widget.drinkData['costPrice']);

  // حقول الدبل الجديدة
  double get _doublePrice => _numOf(widget.drinkData['doublePrice']);
  double get _doubleCostNew {
    final v = widget.drinkData['doubleCost'];
    if (_isNum(v)) return _numOf(v);
    return _numOf(widget.drinkData['doubleCostPrice']);
  }

  // استهلاك الدبل (لو متوفر)، غير كده هنضرب usedAmount × 2
  double get _doubleUsedAmount => _numOf(widget.drinkData['doubleUsedAmount']);

  // تكلفة الدوبل fallback قديم لو مفيش doubleCost
  double get _doubleCostFallback =>
      _numOf(widget.drinkData['doubleCostPrice'], _costPriceSingle * 2.0);

  // خصم الدبل القديم (لو احتجناه لسعر fallback)
  double get _doubleDiscount =>
      _numOf(widget.drinkData['doubleDiscount'], 10.0);

  bool get _supportsServingChoice =>
      _norm(_name) == _norm('قهوة تركي') ||
      _norm(_name) == _norm('قهوة اسبريسو');

  // أسعار الكوفي ميكس (اختياري)
  double get _coffeeMixUnitPrice {
    final mix = widget.drinkData['mixOptions'] as Map<String, dynamic>?;
    final water = _numOf(mix?['waterPrice'], 15);
    final milk = _numOf(mix?['milkPrice'], 25);
    return _mix == 'milk' ? milk : water;
  }

  // سعر الوحدة النهائي
  double get _unitPriceEffective {
    if (_isComplimentary) return 0.0;
    if (_isCoffeeMix) return _coffeeMixUnitPrice;

    if (_supportsServingChoice && _serving == Serving.dbl) {
      return _doublePrice > 0
          ? _doublePrice
          : (_sellPriceBase * 2.0) - _doubleDiscount;
    }
    return _sellPriceBase;
  }

  // تكلفة سنجل/دبل
  double get _unitCostFinal {
    final isDouble = _supportsServingChoice && _serving == Serving.dbl;

    if (!isDouble) {
      if (_isTurkish && _spiced) return _spicedCupCost;
      return _costPriceSingle;
    }

    if (_isTurkish) {
      if (_spiced) {
        final spicedDoubleCupCost = _numOf(
          widget.drinkData['spicedDoubleCupCost'],
        );
        if (spicedDoubleCupCost > 0) return spicedDoubleCupCost;
        if (_spicedCupCost > 0) return _spicedCupCost * 2.0;
      }
      if (_doubleCostNew > 0) return _doubleCostNew;
      return _doubleCostFallback;
    }

    if (_doubleCostNew > 0) return _doubleCostNew;
    return _doubleCostFallback;
  }

  double get _totalPrice => _unitPriceEffective * _qty;
  double get _totalCost => _unitCostFinal * _qty;

  Future<void> _commitSale() async {
    if (_name.isEmpty) {
      setState(() => _fatal = 'اسم المنتج غير موجود.');
      await showErrorDialog(context, _fatal!);
      return;
    }

    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;

      final usedAmountRaw = widget.drinkData['usedAmount'];
      final usedAmount = _isNum(usedAmountRaw) ? _numOf(usedAmountRaw) : null;

      final isDouble = _supportsServingChoice && _serving == Serving.dbl;
      final perUnitConsumption = (usedAmount == null || usedAmount <= 0)
          ? 0.0
          : (isDouble
              ? (_doubleUsedAmount > 0 ? _doubleUsedAmount : usedAmount * 2.0)
              : usedAmount);

      final totalConsumption = perUnitConsumption * _qty;

      final sourceBlendId =
          (widget.drinkData['sourceBlendId'] ?? '').toString().trim();

      final sourceBlendNameRaw =
          (widget.drinkData['sourceBlendName'] ?? '').toString().trim();

      const Map<String, String> sourceBlendOverrides = {
        'قهوة اسبريسو': 'توليفة اسبريسو',
        'شاي': 'شاي كيني',
        'شاى': 'شاي كيني',
      };

      String resolvedSourceBlendName = sourceBlendNameRaw.isNotEmpty
          ? sourceBlendNameRaw
          : (sourceBlendOverrides[_norm(_name)] ?? _name);

      DocumentReference<Map<String, dynamic>>? blendRef;
      if (totalConsumption > 0) {
        if (sourceBlendId.isNotEmpty) {
          blendRef = db.collection('blends').doc(sourceBlendId);
        } else {
          final byName = await db
              .collection('blends')
              .where('name', isEqualTo: resolvedSourceBlendName)
              .limit(1)
              .get();
          if (byName.docs.isNotEmpty) {
            blendRef = byName.docs.first.reference;
          } else {
            throw Exception(
              'مصدر الاستهلاك غير موجود: "$resolvedSourceBlendName"',
            );
          }
        }
      }

      final saleRef = db.collection('sales').doc();

      await db.runTransaction((tx) async {
        if (blendRef != null) {
          final snap = await tx.get(blendRef);
          if (!snap.exists) {
            throw Exception('مصدر الاستهلاك غير موجود في المخزون.');
          }
          final data = snap.data()!;
          final currentStock = _numOf(data['stock']);
          if (currentStock < totalConsumption) {
            throw Exception(
              'المخزون غير كافي في "${data['name'] ?? resolvedSourceBlendName}"',
            );
          }
          tx.update(blendRef, {'stock': currentStock - totalConsumption});
        }

        // قبل: كان بيصفّر total_price لو أجل
        final isComp = _isComplimentary;
        final isDeferred = _isDeferred && !isComp; // الضيافة لا تؤجل
        final unitCost = _unitCostFinal;
        final totalCost = unitCost * _qty;

        // احسب السعر الحقيقي
        final wouldTotalPrice = _isComplimentary ? 0.0 : _totalPrice;
        final profitExpected = wouldTotalPrice - totalCost;
        final unitPriceOut = isComp ? 0.0 : _unitPriceEffective;
        final totalPriceOut = (isComp || isDeferred) ? 0.0 : _totalPrice;
        final profitOut = (isComp || isDeferred)
            ? 0.0
            : (totalCost > 0 ? (_totalPrice - totalCost) : 0.0);
        final note = isDeferred ? _noteCtrl.text.trim() : '';

        tx.set(saleRef, {
          'type': 'drink',
          'drinkId': widget.drinkId,
          'name': _name,
          'drinkName': _name,
          'image': _image,
          'unit': _unit,
          'serving': _supportsServingChoice
              ? (_serving == Serving.dbl ? 'double' : 'single')
              : 'single',
          'quantity': _qty,

          'unit_price': unitPriceOut,
          'total_price': wouldTotalPrice, // ⬅️ مش بنصفّر في الأجل
          'total_cost': totalCost,
          'profit_total': (isComp || isDeferred) ? 0.0 : profitExpected,
          'is_deferred': isDeferred,
          'paid': isDeferred ? false : true, // ⬅️ الأجل يطلع غير مدفوع
          'due_amount': isDeferred ? wouldTotalPrice : 0.0,
          'note': note,
          'list_cost': _costPriceSingle,
          'unit_cost': unitCost,

          'is_complimentary': isComp,
          'spiced': _isTurkish ? _spiced : false,
          'cost_basis': (_isTurkish && _spiced)
              ? (_supportsServingChoice && _serving == Serving.dbl
                  ? 'spicedDoubleCupCost'
                  : 'spicedCupCost')
              : (_supportsServingChoice && _serving == Serving.dbl
                  ? 'doubleCost'
                  : 'costPrice'),

          'consumption': (totalConsumption > 0)
              ? {
                  'sourceBlendId': blendRef?.id,
                  'sourceBlendName': resolvedSourceBlendName,
                  'usedAmountPerUnit': isDouble
                      ? (_doubleUsedAmount > 0
                          ? _doubleUsedAmount
                          : (usedAmount ?? 0.0) * 2.0)
                      : (usedAmount ?? 0.0),
                  'serving': _serving == Serving.dbl ? 'double' : 'single',
                  'totalConsumed': totalConsumption,
                }
              : null,

          'voided': false,
          'created_at': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      nav.pop();
      nav.pushNamedAndRemoveUntil('/', (r) => false);
    } catch (e, st) {
      logError(e, st);
      if (mounted) await showErrorDialog(context, e, st);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final viewInsets =
        EdgeInsets.fromViewPadding(view.viewInsets, view.devicePixelRatio);
    final bottomInset = viewInsets.bottom;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: viewInsets),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset + 12),
        child: SafeArea(
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.zero,
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
                                  Colors.black.withValues(alpha: 0.15),
                                  Colors.black.withValues(alpha: 0.55),
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

                    // Body
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
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

                          if (_isCoffeeMix) ...[
                            Align(
                              alignment: Alignment.center,
                              child: SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'water',
                                    label: Text('مياه'),
                                    icon: Icon(Icons.water_drop_outlined),
                                  ),
                                  ButtonSegment(
                                    value: 'milk',
                                    label: Text('لبن'),
                                    icon: Icon(Icons.local_drink),
                                  ),
                                ],
                                selected: {_mix},
                                onSelectionChanged: _busy
                                    ? null
                                    : (s) => setState(() => _mix = s.first),
                                showSelectedIcon: false,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // === Toggles row ===
                          Row(
                            children: [
                              if (_isTurkish) ...[
                                Expanded(
                                  child: ToggleCard(
                                    title: 'محوّج',
                                    value: _spiced,
                                    onChanged: _busy
                                        ? (_) {}
                                        : (v) => setState(() => _spiced = v),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: ToggleCard(
                                  title: 'ضيافة',
                                  value: _isComplimentary,
                                  onChanged: _busy
                                      ? (_) {}
                                      : (v) => _setComplimentary(v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ToggleCard(
                                  title: 'أجِّل',
                                  value: _isDeferred,
                                  onChanged:
                                      _busy ? (_) {} : (v) => _setDeferred(v),
                                ),
                              ),
                            ],
                          ),

                          DeferredNoteField(
                            controller: _noteCtrl,
                            visible: _isDeferred,
                            enabled: !_busy,
                          ),

                          const SizedBox(height: 12),

                          // سعر الكوب
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'سعر الكوب',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${_unitPriceEffective.toStringAsFixed(2)} جم',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
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
                                        if (_qty > 1) setState(() => _qty -= 1);
                                      },
                                icon: const Icon(Icons.remove),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _totalPrice.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
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
                                border:
                                    Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.warning_amber,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _fatal!,
                                      style: const TextStyle(
                                        color: Colors.orange,
                                      ),
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
                              onPressed:
                                  _busy ? null : () => Navigator.pop(context),
                              child: const Text(
                                'إلغاء',
                                style: TextStyle(
                                  color: Color(0xFF543824),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  const Color(0xFF543824),
                                ),
                              ),
                              onPressed: _busy ? null : _commitSale,
                              child: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
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
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }
}
