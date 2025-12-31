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

  List<String> get _variantOptions;
  String get _variant;
  set _variant(String value);

  List<String> get _roastOptions;
  String get _roast;
  set _roast(String value);

  bool get _showLegacyServing;
  Serving get _serving;
  set _serving(Serving value);

  bool get _showLegacyMix;
  String get _mix;
  set _mix(String value);
  bool get _isCoffeeMix;

  bool get _spiced;
  set _spiced(bool value);

  bool get _spicedEnabled;

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

  late final List<Map<String, dynamic>> _pricingRows;
  late final List<Map<String, dynamic>> _roastUsageRows;
  late final List<String> _variantOptionsList;
  late final List<String> _roastOptionsList;
  late final bool _spicedEnabledValue;

  // Serving (legacy)
  @override
  Serving _serving = Serving.single;

  // Coffee Mix (legacy)
  @override
  String _mix = 'water'; // water | milk

  // Selected options (new schema)
  @override
  String _variant = '';
  @override
  String _roast = '';

  // ==== Spice option ====
  @override
  bool _spiced = false;
  @override
  bool _isComplimentary = false;

  @override
  void initState() {
    super.initState();
    _pricingRows = _extractMapList(widget.drinkData['pricing']);
    _roastUsageRows = _extractMapList(widget.drinkData['roastUsage']);
    _variantOptionsList = _extractOptions(
      widget.drinkData['variants'],
      _pricingRows,
      'variant',
    );
    _roastOptionsList = _extractOptions(
      widget.drinkData['roastLevels'],
      _pricingRows,
      'roast',
    );
    if (_variantOptionsList.isNotEmpty) {
      _variant = _variantOptionsList.first;
    }
    if (_roastOptionsList.isNotEmpty) {
      _roast = _roastOptionsList.first;
    }
    _spicedEnabledValue =
        _readBool(widget.drinkData['spicedEnabled']) ||
        (_supportsServingChoice &&
            (_isNum(widget.drinkData['spicedCupCost']) ||
                _isNum(widget.drinkData['spicedDoubleCupCost'])));
  }
  // --------- Utilities ---------
  String _norm(String s) => s.replaceAll('ى', 'ي').trim();
  bool _isNum(dynamic v) =>
      v is num || double.tryParse(v?.toString() ?? '') != null;
  double _numOf(dynamic v, [double def = 0.0]) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? def;
  }

  bool _readBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = (v ?? '').toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  Map<String, dynamic> _mapOf(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractMapList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => _mapOf(e))
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<String> _readStringList(dynamic raw) {
    if (raw is! List) return const [];
    final result = <String>[];
    for (final item in raw) {
      final value = (item ?? '').toString().trim();
      if (value.isEmpty) continue;
      if (!result.contains(value)) result.add(value);
    }
    return result;
  }

  List<String> _extractOptions(
    dynamic raw,
    List<Map<String, dynamic>> pricingRows,
    String key,
  ) {
    final direct = _readStringList(raw);
    if (direct.isNotEmpty) return direct;
    if (pricingRows.isEmpty) return const [];
    final result = <String>[];
    for (final row in pricingRows) {
      final value = (row[key] ?? '').toString().trim();
      if (value.isEmpty) continue;
      if (!result.contains(value)) result.add(value);
    }
    return result;
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

  @override
  bool get _isCoffeeMix => widget.drinkData['mixOptions'] is Map;
  double get _coffeeMixUnitPrice {
    final mix = widget.drinkData['mixOptions'] as Map<String, dynamic>?;
    final water = _numOf(mix?['waterPrice'], 15);
    final milk = _numOf(mix?['milkPrice'], 25);
    return _mix == 'milk' ? milk : water;
  }

  // سعر الوحدة النهائي
  @override
  List<String> get _variantOptions => _variantOptionsList;
  @override
  List<String> get _roastOptions => _roastOptionsList;
  @override
  bool get _showLegacyServing =>
      _variantOptionsList.isEmpty && _supportsServingChoice;
  @override
  bool get _showLegacyMix => _variantOptionsList.isEmpty && _isCoffeeMix;
  @override
  bool get _spicedEnabled => _spicedEnabledValue;

  Map<String, dynamic>? get _selectedPricing {
    if (_pricingRows.isEmpty) return null;
    final variant = _variant.trim();
    final roast = _roast.trim();
    for (final row in _pricingRows) {
      final rowVariant = (row['variant'] ?? '').toString().trim();
      final rowRoast = (row['roast'] ?? '').toString().trim();
      final variantOk = variant.isEmpty || rowVariant == variant;
      final roastOk = roast.isEmpty || rowRoast == roast;
      if (variantOk && roastOk) return row;
    }
    return null;
  }

  double get _pricingSellPrice =>
      _numOf(_selectedPricing?['sellPrice'], _sellPriceBase);
  double get _pricingCostPrice =>
      _numOf(_selectedPricing?['costPrice'], _costPriceSingle);
  double get _spicedPriceDelta => _numOf(_selectedPricing?['spicedPriceDelta']);
  double get _spicedCostDelta => _numOf(_selectedPricing?['spicedCostDelta']);

  double get _unitPriceEffective {
    if (_pricingRows.isNotEmpty) {
      final base = _pricingSellPrice;
      if (_spicedEnabled && _spiced) {
        return base + _spicedPriceDelta;
      }
      return base;
    }

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
    if (_pricingRows.isNotEmpty) {
      final base = _pricingCostPrice;
      if (_spicedEnabled && _spiced) {
        return base + _spicedCostDelta;
      }
      return base;
    }

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

  String _variantLabel() {
    final roast = _roast.trim();
    final variant = _variant.trim();
    if (roast.isNotEmpty && variant.isNotEmpty) {
      return '$roast $variant';
    }
    if (roast.isNotEmpty) return roast;
    if (variant.isNotEmpty) return variant;
    if (_showLegacyServing) {
      return _serving == Serving.dbl
          ? AppStrings.labelDouble
          : AppStrings.labelSingles;
    }
    if (_showLegacyMix) {
      return _mix == 'milk' ? AppStrings.labelMilk : AppStrings.labelWater;
    }
    return '';
  }

  Map<String, dynamic>? _selectedRoastUsage() {
    if (_roastUsageRows.isEmpty) return null;
    final roast = _roast.trim();
    if (roast.isNotEmpty) {
      for (final row in _roastUsageRows) {
        if ((row['roast'] ?? '').toString().trim() == roast) {
          return row;
        }
      }
      return null;
    }

    for (final row in _roastUsageRows) {
      final rowRoast = (row['roast'] ?? '').toString().trim();
      if (rowRoast.isEmpty) return row;
    }
    if (_roastUsageRows.length == 1) return _roastUsageRows.first;
    return null;
  }

  double _resolveUsedAmount(Map<String, dynamic>? usage, String variant) {
    if (usage == null) return 0.0;
    final usedAmounts = usage['usedAmounts'];
    if (variant.isNotEmpty && usedAmounts is Map) {
      for (final entry in usedAmounts.entries) {
        final key = entry.key.toString().trim();
        if (key == variant) {
          final amount = _numOf(entry.value);
          if (amount > 0) return amount;
        }
      }
    }
    return _numOf(usage['usedAmount']);
  }

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

    final usage = _selectedRoastUsage();
    final perUnitConsumption = _resolveUsedAmount(usage, _variant.trim());
    final totalConsumption = perUnitConsumption * _qty;

    final usedItem = usage == null ? const <String, dynamic>{} : _mapOf(usage['usedItem']);
    final usedCollection = (usedItem['collection'] ?? '').toString().trim();
    final usedId = (usedItem['id'] ?? '').toString().trim();
    final usedName = (usedItem['name'] ?? '').toString().trim();
    final usedVariant = (usedItem['variant'] ?? '').toString().trim();
    final usedLabel = usedName.isEmpty
        ? null
        : (usedVariant.isNotEmpty ? '$usedName - $usedVariant' : usedName);

    final impacts = <StockImpact>[];
    if (totalConsumption > 0 && usedCollection.isNotEmpty && usedId.isNotEmpty) {
      impacts.add(
        StockImpact(
          collection: usedCollection,
          docId: usedId,
          field: 'stock',
          amount: totalConsumption,
          label: usedLabel,
        ),
      );
    }

    final meta = <String, dynamic>{
      'variant': _variant.trim(),
      'roast': _roast.trim(),
      'spiced': _spicedEnabled ? _spiced : false,
      'spicedEnabled': _spicedEnabled,
      'unit_price_effective': _unitPriceEffective,
      'unit_cost_effective': _unitCostFinal,
      if (_pricingRows.isNotEmpty)
        'pricing': {
          'sellPrice': _pricingSellPrice,
          'costPrice': _pricingCostPrice,
          'spicedPriceDelta': _spicedPriceDelta,
          'spicedCostDelta': _spicedCostDelta,
        },
      if (_showLegacyServing)
        'serving': _serving == Serving.dbl ? 'double' : 'single',
      if (_showLegacyMix) 'mix': _mix,
      if (totalConsumption > 0)
        'consumption': {
          'collection': usedCollection,
          'id': usedId,
          'name': usedName,
          'variant': usedVariant,
          'usedAmountPerUnit': perUnitConsumption,
          'totalConsumed': totalConsumption,
        },
    };

    final variantLabel = _variantLabel();

    return CartLine(
      id: CartLine.newId(),
      productId: widget.drinkId,
      name: _name,
      variant: variantLabel.isEmpty ? null : variantLabel,
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










