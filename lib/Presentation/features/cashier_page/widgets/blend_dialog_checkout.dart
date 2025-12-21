part of 'blend_dialog.dart';

mixin _BlendDialogCheckout on _BlendDialogStateBase {
  /// يبني سطر السلة للتوليفة
  @override
  CartLine _buildCartLine() {
    final sel = _selected;
    if (sel == null) {
      throw UserFriendly(AppStrings.errorSelectRoast);
    }
    final grams = _gramsEffective;
    if (grams <= 0) {
      throw UserFriendly(
        _mode == InputMode.grams
            ? AppStrings.errorEnterValidGrams
            : AppStrings.errorEnterValidPrice,
      );
    }

    final gramsDouble = grams.toDouble();
    final price = _totalPrice;
    final cost = _totalCost;

    final impacts = <StockImpact>[
      StockImpact(
        collection: 'blends',
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
    };

    final variant = sel.variant.trim().isEmpty ? null : sel.variant.trim();

    return CartLine(
      id: CartLine.newId(),
      productId: sel.id,
      name: sel.name,
      variant: variant,
      type: 'ready_blend',
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

  @override
  Future<void> _commitSale() async {
    if (_busy) return;
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
      final msg = e is UserFriendly ? e.message : AppStrings.errorUnexpected;
      if (mounted) {
        setState(() => _fatal = msg);
        await showErrorDialog(context, msg);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
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
      await getIt<CartCheckoutService>().commitInvoice(cart: tempCart);
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
}
