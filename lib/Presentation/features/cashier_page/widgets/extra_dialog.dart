import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/cart_state.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/toggle_card.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'dialogs/dialog_image_header.dart';

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

class _ExtraDialogState extends State<ExtraDialog> {
  static final _currencyLabel = AppStrings.currencyEgpLetter;
  static const _unitLabel = AppStrings.labelPieceUnit;
  static const _priceLabel = AppStrings.labelUnitPricePiece;
  static const _stockLabel = AppStrings.labelStock;
  static const _totalLabel = AppStrings.labelInvoiceTotal;
  static const _cancelLabel = AppStrings.dialogCancel;
  static const _confirmLabel = AppStrings.dialogConfirm;

  bool _busy = false;
  String? _fatal;
  int _qty = 1;
  bool _isComplimentary = false;
  bool get _canQuickConfirm => widget.cartMode || widget.onAddToCart != null;

  // ---------- safe getters ----------
  String get _name => (widget.extraData['name'] ?? '').toString();
  String get _image =>
      (widget.extraData['image'] ?? 'assets/cookies.png').toString();

  double _numOf(dynamic v, [double def = 0.0]) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? def;
  }

  int _intOf(dynamic v, [int def = 0]) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? def;
  }

  double get _unitPrice => _numOf(widget.extraData['price_sell']);
  double get _unitCost => _numOf(widget.extraData['cost_unit']);
  int get _stock => _intOf(widget.extraData['stock_units']);

  double get _displayUnitPrice => _isComplimentary ? 0.0 : _unitPrice;
  double get _totalPrice => _isComplimentary ? 0.0 : _unitPrice * _qty;
  double get _totalCost => _unitCost * _qty;

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

  Future<void> _commitSale() async {
    if (_name.isEmpty) {
      setState(() => _fatal = AppStrings.errorItemNameMissing);
      await showErrorDialog(context, _fatal!);
      return;
    }
    if (_qty <= 0) {
      setState(() => _fatal = AppStrings.errorInvalidQuantity);
      await showErrorDialog(context, _fatal!);
      return;
    }

    if (widget.cartMode || widget.onAddToCart != null) {
      setState(() {
        _busy = true;
        _fatal = null;
      });
      try {
        final line = _buildCartLine();
        widget.onAddToCart?.call(line);
        if (!mounted) return;
        Navigator.pop(context, line);
      } catch (e) {
        final msg = e.toString();
        if (mounted) {
          setState(() => _fatal = msg);
          await showErrorDialog(context, msg);
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    setState(() => _busy = true);
    final db = FirebaseFirestore.instance;
    final ref = db.collection('extras').doc(widget.extraId);

    try {
      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw Exception(AppStrings.errorItemNameMissing);
        }
        final data = snap.data() ?? {};
        final curStock = _intOf(data['stock_units']);
        final unitPrice = _numOf(data['price_sell']);
        final unitCost = _numOf(data['cost_unit']);

        if (curStock < _qty) {
          throw Exception(AppStrings.stockNotEnough(curStock, _unitLabel));
        }

        final displayUnitPrice = _isComplimentary ? 0.0 : unitPrice;
        final totalPrice = _isComplimentary ? 0.0 : unitPrice * _qty;
        final totalCost = unitCost * _qty;
        final profit = _isComplimentary ? 0.0 : totalPrice - totalCost;

        tx.update(ref, {
          'stock_units': curStock - _qty,
          'updated_at': FieldValue.serverTimestamp(),
        });

        final saleRef = db.collection('sales').doc();
        tx.set(saleRef, {
          'type': 'extra',
          'source': 'extras',
          'extra_id': widget.extraId,
          'name': _name,
          'variant': (data['variant'] as String?)?.trim(),
          'unit': 'piece',
          'quantity': _qty,
          'unit_price': displayUnitPrice,
          'total_price': totalPrice,
          'total_cost': totalCost,
          'profit_total': profit,
          'is_complimentary': _isComplimentary,
          'is_deferred': false,
          'paid': true,
          'payment_method': 'cash',
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
      Navigator.pop(context, line);
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
    return Localizations.override(
      context: context,
      locale: const Locale('ar'),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(viewInsets: viewInsets),
        child: Directionality(
          textDirection: TextDirection.rtl,
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
                        // ===== Header (Ù†ÙØ³ Ø³ØªØ§ÙŠÙ„ Ø§Ù„Ù…Ø´Ø±ÙˆØ¨Ø§Øª) =====
                        DialogImageHeader(image: _image, title: _name),

                        // ===== Body =====
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$_priceLabel: ${_displayUnitPrice.toStringAsFixed(2)} $_currencyLabel',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '$_stockLabel: $_stock $_unitLabel',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ToggleCard(
                                title: AppStrings.labelHospitality,
                                value: _isComplimentary,
                                busy: _busy,
                                onChanged: (v) =>
                                    setState(() => _isComplimentary = v),
                                leadingIcon: Icons.card_giftcard,
                              ),
                              const SizedBox(height: 12),
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
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.brown.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.brown.shade100,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      _totalLabel,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                    _cancelLabel,
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
                                          _confirmLabel,
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
        ),
      ),
    );
  }
}
