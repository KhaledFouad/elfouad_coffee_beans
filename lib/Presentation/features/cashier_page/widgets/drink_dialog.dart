// lib/Presentation/features/cashier_page/widgets/DrinkDialog.dart
// ignore_for_file: unused_local_variable, unused_element

import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/cart_state.dart';
import 'package:elfouad_coffee_beans/core/di/di.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'dialogs/dialog_image_header.dart';
import 'toggle_card.dart'; // الكارد المعاد استخدامه

part 'drink_dialog_models.dart';
part 'drink_dialog_checkout.dart';
part 'drink_dialog_build.dart';

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

abstract class _DrinkDialogStateBase extends State<DrinkDialog> {
  bool get _busy;
  set _busy(bool value);

  String? get _fatal;
  set _fatal(String? value);

  int get _qty;
  set _qty(int value);

  bool get _canQuickConfirm;

  Serving get _serving;
  set _serving(Serving value);

  bool get _isCoffeeMix;
  String get _mix;
  set _mix(String value);

  bool get _spiced;
  set _spiced(bool value);

  bool get _isComplimentary;
  set _isComplimentary(bool value);

  String get _name;
  String get _image;

  bool get _supportsServingChoice;
  bool get _isTurkish;
  double get _displayUnitPrice;
  double get _totalPrice;

  CartLine _buildCartLine();
  Future<void> _commitSale();
  Future<void> _commitInstantInvoice();
}

class _DrinkDialogState extends _DrinkDialogStateBase
    with _DrinkDialogCheckout, _DrinkDialogBuild {
  @override
  bool _busy = false;
  @override
  String? _fatal;
  @override
  int _qty = 1;
  @override
  bool get _canQuickConfirm => widget.onAddToCart != null;

  // Serving (سنجل/دوبل) للتركي/اسبريسو فقط
  @override
  Serving _serving = Serving.single;

  // Coffee Mix (مياه/لبن)
  @override
  bool get _isCoffeeMix => _name.trim() == 'كوفي ميكس';
  @override
  String _mix = 'water'; // water | milk

  // ==== Spice option (Turkish only) ====
  @override
  bool _spiced = false;
  @override
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
  @override
  String get _name => (widget.drinkData['name'] ?? '').toString();
  @override
  String get _image =>
      (widget.drinkData['image'] ?? 'assets/drinks.jpg').toString();
  String get _unit => (widget.drinkData['unit'] ?? 'cup').toString();

  double get _sellPriceBase => _numOf(widget.drinkData['sellPrice']);

  @override
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

  @override
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

  @override
  double get _totalPrice =>
      _isComplimentary ? 0.0 : _unitPriceEffective * _qty;
  double get _totalCost => _unitCostFinal * _qty;
  @override
  double get _displayUnitPrice =>
      _isComplimentary ? 0.0 : _unitPriceEffective;

  /// يبني CartLine للمشروب
  @override
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

  @override
  Widget build(BuildContext context) {
    return _buildDialog(context);
  }

}
