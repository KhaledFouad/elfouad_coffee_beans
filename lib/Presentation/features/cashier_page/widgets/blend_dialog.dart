// lib/Presentation/features/cashier_page/widgets/blend_dialog.dart
// ignore_for_file: unused_element

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/blends_models.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/cart_state.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/toggle_card.dart';
import 'package:elfouad_coffee_beans/core/di/di.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'dialogs/dialog_action_row.dart';
import 'dialogs/dialog_image_header.dart';

part 'blend_dialog_models.dart';
part 'blend_dialog_load.dart';
part 'blend_dialog_pad.dart';
part 'blend_dialog_components.dart';
part 'blend_dialog_checkout.dart';
part 'blend_dialog_build.dart';
part 'blend_dialog_helpers.dart';

class BlendDialog extends StatefulWidget {
  final BlendGroup group;

  /// وضع الكارت: إضافة للسلة فقط
  final bool cartMode;
  final ValueChanged<CartLine>? onAddToCart;

  const BlendDialog({
    super.key,
    required this.group,
    this.cartMode = false,
    this.onAddToCart,
  });

  @override
  State<BlendDialog> createState() => _BlendDialogState();
}

abstract class _BlendDialogStateBase extends State<BlendDialog> {
  bool get _busy;
  set _busy(bool value);

  String? get _fatal;
  set _fatal(String? value);

  bool get _canQuickConfirm;

  List<String> get _variantOptions;
  String? get _variant;
  set _variant(String? value);

  TextEditingController get _gramsCtrl;
  TextEditingController get _priceCtrl;

  InputMode get _mode;
  set _mode(InputMode value);

  bool get _showPad;
  set _showPad(bool value);
  _PadTarget get _padTarget;
  set _padTarget(_PadTarget value);

  bool get _isComplimentary;
  set _isComplimentary(bool value);
  bool get _isSpiced;
  set _isSpiced(bool value);

  int get _ginsengGrams;
  set _ginsengGrams(int value);

  Map<String, double> get _spicesPricePerKgById;
  Map<String, double> get _spicesCostPerKgById;
  Map<String, bool?> get _spicedEnabledById;
  Map<String, bool?> get _ginsengEnabledById;
  Map<String, double> get _ginsengPricePerKgById;
  Map<String, double> get _ginsengCostPerKgById;

  BlendVariant? get _selected;
  bool get _canSpice;
  bool get _ginsengEnabled;
  double get _sellPerKg;
  double get _pricePerG;
  int get _gramsEffective;
  double get _totalPrice;
  double get _totalCost;
  double get _spicesPricePerKg;
  double get _spicesCostPerKg;
  double get _ginsengPricePerKg;
  double get _ginsengCostPerKg;

  Widget _ginsengCard();
  void _openPad(_PadTarget target);
  void _closePad();
  Widget _numPad({required bool allowDot, required double maxWidth});

  CartLine _buildCartLine();
  Future<void> _commitSale();
  Future<void> _commitInstantInvoice();
}

class _BlendDialogState extends _BlendDialogStateBase
    with
        _BlendDialogLoad,
        _BlendDialogPad,
        _BlendDialogComponents,
        _BlendDialogCheckout,
        _BlendDialogBuild {
  @override
  bool _busy = false;
  @override
  String? _fatal;
  @override
  bool get _canQuickConfirm => widget.cartMode || widget.onAddToCart != null;

  @override
  late final List<String> _variantOptions;
  @override
  String? _variant;

  @override
  final TextEditingController _gramsCtrl = TextEditingController();
  @override
  final TextEditingController _priceCtrl = TextEditingController();
  @override
  InputMode _mode = InputMode.grams;

  @override
  bool _showPad = false;
  @override
  _PadTarget _padTarget = _PadTarget.none;

  // حالات
  @override
  bool _isComplimentary = false;
  @override
  bool _isSpiced = false; // محوّج

  // جينسنج (يظهر فقط لو ginsengEnabled)
  @override
  int _ginsengGrams = 0;

  // من الداتا: تحويج/كجم (سعر/تكلفة) + فلاغ دعم التحويج
  @override
  final Map<String, double> _spicesPricePerKgById = {};
  @override
  final Map<String, double> _spicesCostPerKgById = {};
  @override
  final Map<String, bool?> _spicedEnabledById = {};
  @override
  final Map<String, bool?> _ginsengEnabledById = {};
  @override
  final Map<String, double> _ginsengPricePerKgById = {};
  @override
  final Map<String, double> _ginsengCostPerKgById = {};


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

  int get _grams => _parseInt(_gramsCtrl.text);
  double get _inputPrice => _parseDouble(_priceCtrl.text);

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
    _preloadVariantMeta();
  }

  @override
  BlendVariant? get _selected {
    if (_variant != null) return widget.group.variants[_variant!];
    if (widget.group.variants.containsKey('')) return widget.group.variants[''];
    if (widget.group.variants.length == 1) {
      return widget.group.variants.values.first;
    }
    return null;
  }

  @override
  double get _sellPerKg => _selected?.sellPricePerKg ?? 0.0;
  double get _costPerKg => _selected?.costPricePerKg ?? 0.0;

  double get _sellPerG => _sellPerKg / 1000.0;
  double get _costPerG => _costPerKg / 1000.0;

  bool get _dbSaysCanSpice {
    final sel = _selected;
    if (sel == null) return false;
    final id = sel.id;
    final flag = _spicedEnabledById[id];
    final p = _spicesPricePerKgById[id] ?? 0.0;
    final c = _spicesCostPerKgById[id] ?? 0.0;
    final hasDelta = p > 0.0 || c > 0.0;
    return flag ?? hasDelta;
  }

  @override
  bool get _canSpice => _dbSaysCanSpice;

  @override
  bool get _ginsengEnabled {
    final sel = _selected;
    if (sel == null) return false;
    final id = sel.id;
    final flag = _ginsengEnabledById[id];
    final p = _ginsengPricePerKgById[id] ?? 0.0;
    final c = _ginsengCostPerKgById[id] ?? 0.0;
    final hasDelta = p > 0.0 || c > 0.0;
    return flag ?? hasDelta;
  }
  @override
  double get _spicesPricePerKg {
    final sel = _selected;
    if (!_isSpiced || sel == null || !_canSpice) return 0.0;
    return _spicesPricePerKgById[sel.id] ?? 0.0;
  }

  @override
  double get _spicesCostPerKg {
    final sel = _selected;
    if (!_isSpiced || sel == null || !_canSpice) return 0.0;
    return _spicesCostPerKgById[sel.id] ?? 0.0;
  }

  double get _spicePricePerG => _spicesPricePerKg / 1000.0;
  double get _spiceCostPerG => _spicesCostPerKg / 1000.0;


  @override
  double get _ginsengPricePerKg {
    final sel = _selected;
    if (!_ginsengEnabled || sel == null) return 0.0;
    return _ginsengPricePerKgById[sel.id] ?? 0.0;
  }

  @override
  double get _ginsengCostPerKg {
    final sel = _selected;
    if (!_ginsengEnabled || sel == null) return 0.0;
    return _ginsengCostPerKgById[sel.id] ?? 0.0;
  }

  double get _ginsengPricePerG => _ginsengPricePerKg / 1000.0;
  double get _ginsengCostPerG => _ginsengCostPerKg / 1000.0;
  @override
  int get _gramsEffective {
    if (_mode == InputMode.grams) return _grams;
    final perG = _sellPerG + (_isSpiced && _canSpice ? _spicePricePerG : 0.0);
    if (perG <= 0) return 0;
    final g = (_inputPrice / perG).floor();
    return g.clamp(0, 1000000);
  }

  // أجزاء السعر/التكلفة (بن + تحويج + جينسنج)
  double get _beansAmount => _sellPerG * _gramsEffective;
  double get _spiceAmount =>
      (_isSpiced && _canSpice) ? (_gramsEffective * _spicePricePerG) : 0.0;
  double get _ginsengPriceAmount => _ginsengGrams * _ginsengPricePerG;

  double get _beansCostAmount => _costPerG * _gramsEffective;
  double get _spiceCostAmount =>
      (_isSpiced && _canSpice) ? (_gramsEffective * _spiceCostPerG) : 0.0;
  double get _ginsengCostAmount => _ginsengGrams * _ginsengCostPerG;

  @override
  double get _pricePerG =>
      _sellPerG + (_isSpiced && _canSpice ? _spicePricePerG : 0.0);

  @override
  double get _totalPrice =>
      _isComplimentary ? 0.0 : _beansAmount + _spiceAmount + _ginsengPriceAmount;

  @override
  double get _totalCost =>
      _beansCostAmount + _spiceCostAmount + _ginsengCostAmount;

  @override
  Widget build(BuildContext context) {
    return _buildDialog(context);
  }

  @override
  void dispose() {
    _gramsCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }
}




