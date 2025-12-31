// lib/Presentation/features/cashier_page/widgets/singleDialog.dart
// ignore_for_file: unused_local_variable, unused_element

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/cart_state.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/singles_models.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/toggle_card.dart';
import 'package:elfouad_coffee_beans/core/di/di.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'dialogs/dialog_action_row.dart';
import 'dialogs/dialog_image_header.dart';

part 'single_dialog_models.dart';
part 'single_dialog_load.dart';
part 'single_dialog_pad.dart';
part 'single_dialog_components.dart';
part 'single_dialog_checkout.dart';
part 'single_dialog_build.dart';
part 'single_dialog_helpers.dart';

class SingleDialog extends StatefulWidget {
  final SingleGroup group;

  /// لو true يبقى الشاشة دي شغالة كـ "إضافة للسلة" بس
  final bool cartMode;

  /// كول باك يُستدعى عند إضافة صنف جديد للسلة
  final ValueChanged<CartLine>? onAddToCart;

  const SingleDialog({
    super.key,
    required this.group,
    this.cartMode = false,
    this.onAddToCart,
  });

  @override
  State<SingleDialog> createState() => _SingleDialogState();
}

abstract class _SingleDialogStateBase extends State<SingleDialog> {
  bool get _busy;
  set _busy(bool value);

  String? get _fatal;
  set _fatal(String? value);

  bool get _canQuickConfirm;

  List<String> get _roastOptions;
  String? get _roast;
  set _roast(String? value);

  Map<String, double> get _stockByVariantId;
  Map<String, double> get _spicesPriceByVariantId;
  Map<String, double> get _spicesCostByVariantId;
  Map<String, bool?> get _spicedEnabledByVariantId;
  Map<String, bool?> get _ginsengEnabledByVariantId;
  Map<String, double> get _ginsengPricePerKgByVariantId;
  Map<String, double> get _ginsengCostPerKgByVariantId;

  bool get _stocksLoading;
  set _stocksLoading(bool value);

  TextEditingController get _gramsCtrl;
  TextEditingController get _moneyCtrl;

  CalcMode get _mode;
  set _mode(CalcMode value);

  bool get _isComplimentary;
  set _isComplimentary(bool value);
  bool get _isSpiced;
  set _isSpiced(bool value);

  int get _ginsengGrams;
  set _ginsengGrams(int value);

  bool get _showPad;
  set _showPad(bool value);
  _PadTarget get _padTarget;
  set _padTarget(_PadTarget value);

  SingleVariant? get _selected;
  bool get _canSpice;
  bool get _ginsengEnabled;
  double get _sellPerKg;
  double get _pricePerG;
  int get _grams;
  double get _totalPrice;

  Widget _ginsengCard();
  void _openPad(_PadTarget target);
  void _closePad();
  Widget _numPad({required bool allowDot});

  CartLine _buildCartLine();
  Future<void> _commitSale();
  Future<void> _commitInstantInvoice();
}

class _SingleDialogState extends _SingleDialogStateBase
    with
        _SingleDialogLoad,
        _SingleDialogPad,
        _SingleDialogComponents,
        _SingleDialogCheckout,
        _SingleDialogBuild {
  @override
  bool _busy = false;
  @override
  String? _fatal;
  @override
  bool get _canQuickConfirm => widget.cartMode || widget.onAddToCart != null;

  // roast (variant)
  @override
  late final List<String> _roastOptions;
  @override
  String? _roast;

  @override
  final Map<String, double> _stockByVariantId = {};
  @override
  final Map<String, double> _spicesPriceByVariantId =
      {}; // سعر التحويج/كجم (للبيع)
  @override
  final Map<String, double> _spicesCostByVariantId = {}; // تكلفة التحويج/كجم
  @override
  final Map<String, bool?> _spicedEnabledByVariantId = {};
  @override
  final Map<String, bool?> _ginsengEnabledByVariantId = {};
  @override
  final Map<String, double> _ginsengPricePerKgByVariantId = {};
  @override
  final Map<String, double> _ginsengCostPerKgByVariantId = {};
  @override
  bool _stocksLoading = true;

  @override
  final TextEditingController _gramsCtrl = TextEditingController();
  @override
  final TextEditingController _moneyCtrl = TextEditingController();

  @override
  CalcMode _mode = CalcMode.byGrams;

  // محوّج
  @override
  bool _isComplimentary = false;
  @override
  bool _isSpiced = false;

  // جينسنج
  @override
  int _ginsengGrams = 0;

  // --- نومباد داخلي ---
  @override
  bool _showPad = false;
  @override
  _PadTarget _padTarget = _PadTarget.none;

  int _parseInt(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^0-9]'), '');
    final v = int.tryParse(cleaned) ?? 0;
    return v.clamp(0, 1000000);
  }

  double _parseDouble(String s) {
    final cleaned = s
        .replaceAll(',', '.')
        .replaceAll('٫', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _roastOptions =
        widget.group.variants.keys
            .map((e) => e.toString().trim())
            .toSet()
            .toList()
          ..sort((a, b) {
            if (a.isEmpty && b.isEmpty) return 0;
            if (a.isEmpty) return 1;
            if (b.isEmpty) return -1;
            return a.compareTo(b);
          });
    _roast = _roastOptions.isNotEmpty ? _roastOptions.first : null;
    _preloadStocks();
  }

  @override
  SingleVariant? get _selected {
    final key = _roast ?? '';
    return widget.group.variants[key];
  }

  // يحقّ التحويج لو في الداتابيز قيم (سعر/تكلفة) للتحويج
  @override
  bool get _canSpice {
    final sel = _selected;
    if (sel == null) return false;
    final flag = _spicedEnabledByVariantId[sel.id];
    final p = _spicesPriceByVariantId[sel.id] ?? 0.0;
    final c = _spicesCostByVariantId[sel.id] ?? 0.0;
    final hasDelta = p > 0.0 || c > 0.0;
    return flag ?? hasDelta;
  }

  @override
  bool get _ginsengEnabled {
    final sel = _selected;
    if (sel == null) return false;
    final flag = _ginsengEnabledByVariantId[sel.id];
    final p = _ginsengPricePerKgByVariantId[sel.id] ?? 0.0;
    final c = _ginsengCostPerKgByVariantId[sel.id] ?? 0.0;
    final hasDelta = p > 0.0 || c > 0.0;
    return flag ?? hasDelta;
  }

  // أسعار بن (من الموديل)
  @override
  double get _sellPerKg => _selected?.sellPricePerKg ?? 0.0;
  double get _costPerKg => _selected?.costPricePerKg ?? 0.0;
  double get _sellPerG => _sellPerKg / 1000.0;
  double get _costPerG => _costPerKg / 1000.0;

  // تحويج (من الداتابيز)
  double get _spicesPricePerKg {
    final sel = _selected;
    if (!_isSpiced || sel == null || !_canSpice) return 0.0;
    return _spicesPriceByVariantId[sel.id] ?? 0.0;
  }

  double get _spicesCostPerKg {
    final sel = _selected;
    if (!_isSpiced || sel == null || !_canSpice) return 0.0;
    return _spicesCostByVariantId[sel.id] ?? 0.0;
  }

  double get _spicePricePerG => _spicesPricePerKg / 1000.0;
  double get _spiceCostPerG => _spicesCostPerKg / 1000.0;

  double get _ginsengPricePerKg {
    final sel = _selected;
    if (!_ginsengEnabled || sel == null) return 0.0;
    return _ginsengPricePerKgByVariantId[sel.id] ?? 0.0;
  }

  double get _ginsengCostPerKg {
    final sel = _selected;
    if (!_ginsengEnabled || sel == null) return 0.0;
    return _ginsengCostPerKgByVariantId[sel.id] ?? 0.0;
  }

  double get _ginsengPricePerG => _ginsengPricePerKg / 1000.0;
  double get _ginsengCostPerG => _ginsengCostPerKg / 1000.0;

  @override
  int get _grams {
    if (_mode == CalcMode.byMoney) {
      final money = _parseDouble(_moneyCtrl.text);
      if (money <= 0) return 0;
      final effectivePerG =
          _sellPerG + (_isSpiced && _canSpice ? _spicePricePerG : 0.0);
      if (effectivePerG <= 0) return 0;
      final g = (money / effectivePerG).floor();
      return g.clamp(0, 1000000);
    } else {
      return _parseInt(_gramsCtrl.text);
    }
  }

  // مبالغ السعر/التكلفة (بن + تحويج + جينسنج)
  double get _beansAmount => _sellPerG * _grams;
  double get _spiceAmount =>
      (_isSpiced && _canSpice) ? (_grams * _spicePricePerG) : 0.0;
  double get _ginsengPriceAmount => _ginsengGrams * _ginsengPricePerG;

  double get _beansCostAmount => _costPerG * _grams;
  double get _spiceCostAmount =>
      (_isSpiced && _canSpice) ? (_grams * _spiceCostPerG) : 0.0;
  double get _ginsengCostAmount => _ginsengGrams * _ginsengCostPerG;

  @override
  double get _pricePerG =>
      _sellPerG + (_isSpiced && _canSpice ? _spicePricePerG : 0.0);

  @override
  double get _totalPrice =>
      _isComplimentary ? 0.0 : _beansAmount + _spiceAmount + _ginsengPriceAmount;

  double get _totalCost =>
      _beansCostAmount + _spiceCostAmount + _ginsengCostAmount;

  /// يبني سطر سلة (CartLine)
  @override
  CartLine _buildCartLine() {
    final sel = _selected;
    if (sel == null) {
      throw UserFriendly(AppStrings.errorSelectRoast);
    }
    final grams = _grams;
    if (grams <= 0) {
      throw UserFriendly(AppStrings.errorEnterValidGramsOrPrice);
    }

    final price = _totalPrice;
    final cost = _totalCost;
    final gramsDouble = grams.toDouble();

    final impacts = <StockImpact>[
      StockImpact(
        collection: 'singles',
        docId: sel.id,
        field: 'stock',
        amount: gramsDouble,
        label: sel.name,
      ),
    ];

    final meta = <String, dynamic>{
      'spiced': _isSpiced && _canSpice,
      'ginseng_grams': _ginsengGrams,
      'mode': _mode.name,
      'price_per_g_effective': _pricePerG,
      'spice_price_per_kg': _spicesPricePerKg,
      'spice_cost_per_kg': _spicesCostPerKg,
      'ginseng_price_per_kg': _ginsengPricePerKg,
      'ginseng_cost_per_kg': _ginsengCostPerKg,
    };

    final variant = sel.variant.trim().isEmpty ? null : sel.variant.trim();

    return CartLine(
      id: CartLine.newId(),
      productId: sel.id,
      name: sel.name,
      variant: variant,
      type: 'single',
      unit: 'g',
      image: sel.image,
      quantity: gramsDouble,
      grams: gramsDouble,
      unitPrice: gramsDouble > 0 ? (price / gramsDouble) : 0.0,
      unitCost: gramsDouble > 0 ? (cost / gramsDouble) : 0.0,
      lineTotalPrice: price,
      lineTotalCost: cost,
      isComplimentary: _isComplimentary,
      isDeferred: false,
      note: '',
      meta: meta,
      impacts: impacts,
    );
  }

  // ===== نومباد داخلي =====
  @override
  Widget build(BuildContext context) {
    return _buildDialog(context);
  }

  @override
  void dispose() {
    _gramsCtrl.dispose();
    _moneyCtrl.dispose();
    super.dispose();
  }
}


