part of 'extra_dialog.dart';

mixin _ExtraDialogCheckout on _ExtraDialogStateBase {
  @override
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
          throw Exception(
            AppStrings.stockNotEnough(curStock, _ExtraDialogState._unitLabel),
          );
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
