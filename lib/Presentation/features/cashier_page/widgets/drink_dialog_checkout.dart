part of 'drink_dialog.dart';

mixin _DrinkDialogCheckout on _DrinkDialogStateBase {
  @override
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
}
