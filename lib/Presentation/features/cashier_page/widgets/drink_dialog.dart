// lib/Presentation/features/cashier_page/widgets/DrinkDialog.dart
// ignore_for_file: unused_local_variable, unused_element

import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/cart_state.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'dialogs/dialog_image_header.dart';
import 'toggle_card.dart'; // الكارد المعاد استخدامه

enum Serving { single, dbl }

class DrinkDialog extends StatefulWidget {
  final String drinkId;
  final Map<String, dynamic> drinkData;

  /// كول باك لإضافة المشروب إلى السلة
  final ValueChanged<CartLine>? onAddToCart;

  const DrinkDialog({
    super.key,
    required this.drinkId,
    required this.drinkData,
    this.onAddToCart,
  });

  @override
  State<DrinkDialog> createState() => _DrinkDialogState();
}

class _DrinkDialogState extends State<DrinkDialog> {
  bool _busy = false;
  String? _fatal;
  int _qty = 1;
  bool get _canQuickConfirm => widget.onAddToCart != null;

  // Serving (سنجل/دوبل) للتركي/اسبريسو فقط
  Serving _serving = Serving.single;

  // Coffee Mix (مياه/لبن)
  bool get _isCoffeeMix => _name.trim() == 'كوفي ميكس';
  String _mix = 'water'; // water | milk

  // ==== Spice option (Turkish only) ====
  bool _spiced = false;
  bool _isComplimentary = false;

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

  bool get _isTurkish {
    final n = _norm(_name);
    return n == _norm('قهوة تركي');
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

  double get _totalPrice =>
      _isComplimentary ? 0.0 : _unitPriceEffective * _qty;
  double get _totalCost => _unitCostFinal * _qty;
  double get _displayUnitPrice =>
      _isComplimentary ? 0.0 : _unitPriceEffective;

  /// يبني CartLine للمشروب
  CartLine _buildCartLine() {
    if (_name.isEmpty) {
      throw Exception(AppStrings.errorProductNameMissing);
    }

    final qtyDouble = _qty.toDouble();
    final price = _totalPrice;
    final cost = _totalCost;
    final unitPrice = _isComplimentary ? 0.0 : _unitPriceEffective;

    // استهلاك البن من توليفة (لو موجود)
    final usedAmountRaw = widget.drinkData['usedAmount'];
    final usedAmount = _isNum(usedAmountRaw) ? _numOf(usedAmountRaw) : null;

    final isDouble = _supportsServingChoice && _serving == Serving.dbl;
    final perUnitConsumption = (usedAmount == null || usedAmount <= 0)
        ? 0.0
        : (isDouble
              ? (_doubleUsedAmount > 0 ? _doubleUsedAmount : usedAmount * 2.0)
              : usedAmount);

    final totalConsumption = perUnitConsumption * _qty;

    final sourceBlendId = (widget.drinkData['sourceBlendId'] ?? '')
        .toString()
        .trim();

    final sourceBlendNameRaw = (widget.drinkData['sourceBlendName'] ?? '')
        .toString()
        .trim();

    const Map<String, String> sourceBlendOverrides = {
      'قهوة اسبريسو': 'توليفة اسبريسو',
      'شاي': 'شاي كيني',
      'شاى': 'شاي كيني',
    };

    String resolvedSourceBlendName = sourceBlendNameRaw.isNotEmpty
        ? sourceBlendNameRaw
        : (sourceBlendOverrides[_norm(_name)] ?? _name);

    final impacts = <StockImpact>[];
    if (totalConsumption > 0 && sourceBlendId.isNotEmpty) {
      impacts.add(
        StockImpact(
          collection: 'blends',
          docId: sourceBlendId,
          field: 'stock',
          amount: totalConsumption,
          label: resolvedSourceBlendName,
        ),
      );
    }

    final meta = <String, dynamic>{
      'serving': _supportsServingChoice
          ? (_serving == Serving.dbl ? 'double' : 'single')
          : 'single',
      'spiced': _isTurkish ? _spiced : false,
      'isTurkish': _isTurkish,
      'isCoffeeMix': _isCoffeeMix,
      if (_isCoffeeMix) 'mix': _mix,
      'unit_price_effective': _unitPriceEffective,
      'list_cost': _costPriceSingle,
      'unit_cost_effective': _unitCostFinal,
      'cost_basis': (_isTurkish && _spiced)
          ? (_supportsServingChoice && _serving == Serving.dbl
                ? 'spicedDoubleCupCost'
                : 'spicedCupCost')
          : (_supportsServingChoice && _serving == Serving.dbl
                ? 'doubleCost'
                : 'costPrice'),
      if (totalConsumption > 0)
        'consumption': {
          'sourceBlendId': sourceBlendId.isEmpty ? null : sourceBlendId,
          'sourceBlendName': resolvedSourceBlendName,
          'usedAmountPerUnit': perUnitConsumption,
          'serving': _serving == Serving.dbl ? 'double' : 'single',
          'totalConsumed': totalConsumption,
        },
    };

    return CartLine(
      id: CartLine.newId(),
      productId: widget.drinkId,
      name: _name,
      variant: null,
      type: 'drink',
      unit: _unit,
      image: _image,
      quantity: qtyDouble,
      grams: 0.0,
      unitPrice: unitPrice,
      unitCost: qtyDouble > 0 ? (cost / qtyDouble) : 0.0,
      lineTotalPrice: price,
      lineTotalCost: cost,
      isComplimentary: _isComplimentary,
      isDeferred: false,
      note: '',
      meta: meta,
      impacts: impacts,
    );
  }

  Future<void> _commitSale() async {
    if (_name.isEmpty) {
      setState(() => _fatal = AppStrings.errorProductNameMissing);
      await showErrorDialog(context, _fatal!);
      return;
    }

    setState(() => _busy = true);
    try {
      final line = _buildCartLine();
      widget.onAddToCart?.call(line);
      if (!mounted) return;
      Navigator.pop(context, line);
    } catch (e) {
      if (mounted) {
        setState(() => _fatal = AppStrings.errorUnexpected);
        await showErrorDialog(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commitInstantInvoice() async {
    if (!_canQuickConfirm || _busy) return;
    setState(() {
      _busy = true;
      _fatal = null;
    });
    try {
      final line = _buildCartLine();
      final tempCart = CartState();
      tempCart.addLine(line);
      if (line.isComplimentary) {
        tempCart.setInvoiceComplimentary(true);
      }
      await CartCheckout.commitInvoice(cart: tempCart);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(
        const SnackBar(content: Text(AppStrings.dialogInvoiceCreated)),
      );
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
    final viewInsets = EdgeInsets.fromViewPadding(
      view.viewInsets,
      view.devicePixelRatio,
    );
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
                    DialogImageHeader(image: _image, title: _name),

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
                                    label: Text(AppStrings.labelSingles),
                                    icon: Icon(Icons.coffee_outlined),
                                  ),
                                  ButtonSegment(
                                    value: Serving.dbl,
                                    label: Text(AppStrings.labelDouble),
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
                                    label: Text(AppStrings.labelWater),
                                    icon: Icon(Icons.water_drop_outlined),
                                  ),
                                  ButtonSegment(
                                    value: 'milk',
                                    label: Text(AppStrings.labelMilk),
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

                          // === Toggles row (????? ??? ??????) ===
                          Row(
                            children: [
                              Expanded(
                                child: ToggleCard(
                                  title: AppStrings.labelHospitality,
                                  value: _isComplimentary,
                                  busy: _busy,
                                  onChanged: (v) =>
                                      setState(() => _isComplimentary = v),
                                  leadingIcon: Icons.card_giftcard,
                                ),
                              ),
                              if (_isTurkish) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ToggleCard(
                                    title: AppStrings.labelSpiced,
                                    value: _spiced,
                                    busy: _busy,
                                    onChanged: (v) =>
                                        setState(() => _spiced = v),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),

                          // سعر الكوب
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                AppStrings.labelCupPrice,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${_displayUnitPrice.toStringAsFixed(2)} ${AppStrings.labelGramsShort}',
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
                                        if (_qty > 1) {
                                          setState(() => _qty -= 1);
                                        }
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
                                  AppStrings.labelInvoiceTotal,
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
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
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
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text(
                                AppStrings.dialogCancel,
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
                              onLongPress: _busy || !_canQuickConfirm
                                  ? null
                                  : _commitInstantInvoice,
                              child: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      AppStrings.dialogConfirm,
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
}

