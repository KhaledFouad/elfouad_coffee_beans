part of 'custom_blends_page.dart';

mixin _CustomBlendsCheckout on _CustomBlendsStateBase {
  bool get _hasInvalidLine {
    for (final l in _lines) {
      if (l.item == null) return true;
      if (l.gramsEffective <= 0) return true;
    }
    return false;
  }

  @override
  CartLine _buildCartLine() {
    if (_allItems.isEmpty) {
      throw UserFriendly('لم يتم تحميل الأصناف بعد.');
    }
    if (_lines.isEmpty || _hasInvalidLine) {
      throw UserFriendly('من فضلك اختر الأصناف وأدخل الكميات.');
    }
    final customTitle = _titleCtrl.text.trim();
    if (customTitle.isEmpty) {
      throw UserFriendly(AppStrings.errorCustomBlendTitleRequired);
    }

    final Map<String, int> gramsBySinglesId = {};
    final Map<String, int> gramsByBlendsId = {};
    final Map<String, String> labelBySinglesId = {};
    final Map<String, String> labelByBlendsId = {};
    for (final l in _lines) {
      final it = l.item!;
      final g = l.gramsEffective;
      if (it.source == ItemSource.singles) {
        gramsBySinglesId[it.id] = (gramsBySinglesId[it.id] ?? 0) + g;
        labelBySinglesId[it.id] = it.fullLabel;
      } else {
        gramsByBlendsId[it.id] = (gramsByBlendsId[it.id] ?? 0) + g;
        labelByBlendsId[it.id] = it.fullLabel;
      }
    }

    final isComp = _isComplimentary;
    final isDef = _isDeferred && !isComp;
    final totalPriceWould = isComp ? 0.0 : _totalPriceWould;
    final totalBeansCost = _lines.fold<double>(
      0.0,
      (s, l) => s + (l.item!.costPerG * l.gramsEffective),
    );
    final totalSpiceCost = _spiceCostAmount;
    final totalCost = totalBeansCost + totalSpiceCost + _ginsengCostAmount;
    final gramsTotal = _sumGrams.toDouble();

    final components = _lines.map((l) {
      final it = l.item!;
      final g = l.gramsEffective.toDouble();
      final pricePerGOut = isComp ? 0.0 : it.sellPerG;
      final compSpiceRate = (isComp || !_isSpiced || !it.supportsSpice)
          ? 0.0
          : it.spicesPricePerKg;
      final compSpiceCostRate = (isComp || !_isSpiced || !it.supportsSpice)
          ? 0.0
          : it.spicesCostPerKg;

      return {
        'item_id': it.id,
        'source': it.source == ItemSource.singles ? 'singles' : 'blends',
        'name': it.name,
        'variant': it.variant,
        'unit': 'g',
        'grams': g,
        'price_per_kg': it.sellPricePerKg,
        'price_per_g': pricePerGOut,
        'line_total_price': pricePerGOut * g,
        'cost_per_kg': it.costPricePerKg,
        'cost_per_g': it.costPerG,
        'line_total_cost': it.costPerG * g,
        'spice_rate_per_kg': compSpiceRate,
        'spice_cost_per_kg': compSpiceCostRate,
      };
    }).toList();

    final impacts = <StockImpact>[
      for (final entry in gramsBySinglesId.entries)
        StockImpact(
          collection: 'singles',
          docId: entry.key,
          field: 'stock',
          amount: entry.value.toDouble(),
          label: labelBySinglesId[entry.key],
        ),
      for (final entry in gramsByBlendsId.entries)
        StockImpact(
          collection: 'blends',
          docId: entry.key,
          field: 'stock',
          amount: entry.value.toDouble(),
          label: labelByBlendsId[entry.key],
        ),
    ];

    final meta = <String, dynamic>{
      'components': components,
      'custom_title': customTitle,
      'spiced': _isSpiced && _canSpiceAny,
      'ginseng_grams': _ginsengGrams,
      'ginseng_price_per_g': _CustomBlendsPageState._ginsengPricePerG,
      'ginseng_cost_per_g': _CustomBlendsPageState._ginsengCostPerG,
      'spice_rate_per_kg': _effectiveSpiceRatePerKg,
      'spice_cost_per_kg': _effectiveSpiceCostPerKg,
      'spice_amount': isComp ? 0.0 : _spiceAmount,
      'ginseng_price_amount': isComp ? 0.0 : _ginsengPriceAmount,
      'ginseng_cost_amount': _ginsengCostAmount,
    };

    return CartLine(
      id: CartLine.newId(),
      productId: 'custom_blend',
      name: 'خلطة مخصصة',
      variant: customTitle,
      type: 'custom_blend',
      unit: 'g',
      image: 'assets/custom.jpg',
      quantity: 0,
      grams: gramsTotal,
      unitPrice: gramsTotal > 0 ? (totalPriceWould / gramsTotal) : 0.0,
      unitCost: gramsTotal > 0 ? (totalCost / gramsTotal) : 0.0,
      lineTotalPrice: totalPriceWould,
      lineTotalCost: totalCost,
      isComplimentary: isComp,
      isDeferred: isDef,
      note: isDef ? _noteCtrl.text.trim() : '',
      meta: meta,
      impacts: impacts,
    );
  }

  @override
  Future<void> _commitSale() async {
    if (_allItems.isEmpty) {
      setState(() => _fatal = 'لم يتم تحميل الأصناف بعد.');
      return;
    }
    if (_lines.isEmpty || _hasInvalidLine) {
      setState(() => _fatal = 'من فضلك اختر الأصناف وأدخل الكميات.');
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
        final msg = e is UserFriendly
            ? e.message
            : (e is FirebaseException
                  ? 'خطأ في البيانات (${e.code})'
                  : 'حدث خطأ غير متوقع.');
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text(AppStrings.dialogBlendAddFailed),
            content: SingleChildScrollView(child: Text(msg)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(AppStrings.dialogOk),
              ),
            ],
          ),
        );
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    // If not in cart mode, just add to cart.
    final line = _buildCartLine();
    widget.onAddToCart?.call(line);
    if (!mounted) return;
    Navigator.pop(context, line);
  }

  @override
  Future<void> _commitInstantInvoice() async {
    if (_busy || !_canQuickConfirm) return;
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
