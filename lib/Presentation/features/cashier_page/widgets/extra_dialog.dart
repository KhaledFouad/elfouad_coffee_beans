import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/cart_state.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/toggle_card.dart';
import 'package:elfouad_coffee_beans/core/di/di.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'dialogs/dialog_image_header.dart';

part 'extra_dialog_checkout.dart';
part 'extra_dialog_build.dart';

class ExtraDialog extends StatefulWidget {
  final String extraId;
  final Map<String, dynamic> extraData;

  final bool cartMode;
  final ValueChanged<CartLine>? onAddToCart;

  const ExtraDialog({
    super.key,
    required this.extraId,
    required this.extraData,
    this.cartMode = false,
    this.onAddToCart,
  });

  @override
  State<ExtraDialog> createState() => _ExtraDialogState();
}

abstract class _ExtraDialogStateBase extends State<ExtraDialog> {
  bool get _busy;
  set _busy(bool value);

  String? get _fatal;
  set _fatal(String? value);

  int get _qty;
  set _qty(int value);

  bool get _isComplimentary;
  set _isComplimentary(bool value);

  bool get _canQuickConfirm;

  String get _name;
  String get _image;
  int get _stock;
  double get _displayUnitPrice;
  double get _totalPrice;

  double _numOf(dynamic v);
  int _intOf(dynamic v);

  CartLine _buildCartLine();
  Future<void> _commitSale();
  Future<void> _commitInstantInvoice();
}

class _ExtraDialogState extends _ExtraDialogStateBase
    with _ExtraDialogCheckout, _ExtraDialogBuild {
  static final _currencyLabel = AppStrings.currencyEgpLetter;
  static const _unitLabel = AppStrings.labelPieceUnit;
  static const _priceLabel = AppStrings.labelUnitPricePiece;
  static const _stockLabel = AppStrings.labelStock;
  static const _totalLabel = AppStrings.labelInvoiceTotal;
  static const _cancelLabel = AppStrings.dialogCancel;
  static const _confirmLabel = AppStrings.dialogConfirm;

  @override
  bool _busy = false;
  @override
  String? _fatal;
  @override
  int _qty = 1;
  @override
  bool _isComplimentary = false;
  @override
  bool get _canQuickConfirm => widget.cartMode || widget.onAddToCart != null;

  // ---------- safe getters ----------
  @override
  String get _name => (widget.extraData['name'] ?? '').toString();
  @override
  String get _image =>
      (widget.extraData['image'] ?? 'assets/cookies.png').toString();

  @override
  double _numOf(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  @override
  int _intOf(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  double get _unitPrice => _numOf(widget.extraData['price_sell']);
  double get _unitCost => _numOf(widget.extraData['cost_unit']);
  @override
  int get _stock => _intOf(widget.extraData['stock_units']);

  @override
  double get _displayUnitPrice => _isComplimentary ? 0.0 : _unitPrice;
  @override
  double get _totalPrice => _isComplimentary ? 0.0 : _unitPrice * _qty;
  double get _totalCost => _unitCost * _qty;

  @override
  CartLine _buildCartLine() {
    if (_name.isEmpty) {
      throw Exception(AppStrings.errorItemNameMissing);
    }
    if (_qty <= 0) {
      throw Exception(AppStrings.errorInvalidQuantity);
    }

    final variantRaw = (widget.extraData['variant'] as String?)?.trim() ?? '';
    final variant = variantRaw.isEmpty ? null : variantRaw;

    return CartLine(
      id: CartLine.newId(),
      productId: widget.extraId,
      name: _name,
      variant: variant,
      type: 'extra',
      unit: 'piece',
      image: _image,
      quantity: _qty.toDouble(),
      grams: 0,
      unitPrice: _displayUnitPrice,
      unitCost: _unitCost,
      lineTotalPrice: _totalPrice,
      lineTotalCost: _totalCost,
      isComplimentary: _isComplimentary,
      isDeferred: false,
      note: '',
      meta: {'variant': variant},
      impacts: [
        StockImpact(
          collection: 'extras',
          docId: widget.extraId,
          field: 'stock_units',
          amount: _qty.toDouble(),
          label: _name,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildDialog(context);
  }

}
