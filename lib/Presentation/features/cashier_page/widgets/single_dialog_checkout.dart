part of 'single_dialog.dart';

mixin _SingleDialogCheckout on _SingleDialogStateBase {
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
