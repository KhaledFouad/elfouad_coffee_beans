part of 'blend_dialog.dart';

mixin _BlendDialogBuild on _BlendDialogStateBase {
  Widget _buildDialog(BuildContext context) {
    final name = widget.group.name;
    final image = widget.group.image;

    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final viewInsets = EdgeInsets.fromViewPadding(
      view.viewInsets,
      view.devicePixelRatio,
    );
    final bottomInset = viewInsets.bottom;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: viewInsets),
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
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    DialogImageHeader(image: image, title: name),

                    // Body
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (_variantOptions.isNotEmpty) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _variantOptions.map((r) {
                                  final selected = (_variant ?? '') == r;
                                  final v = widget.group.variants[r];
                                  final stock = v?.stock ?? double.infinity;
                                  final disabled = stock <= 0;
                                  final label = disabled
                                      ? '$r (${AppStrings.labelUnavailable})'
                                      : r;
                                  return ChoiceChip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (disabled)
                                          const Icon(Icons.block, size: 16),
                                        if (disabled) const SizedBox(width: 6),
                                        Text(
                                          label,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    selected: selected,
                                    onSelected: _busy || disabled
                                        ? null
                                        : (vSel) {
                                            if (!vSel) return;
                                            setState(() {
                                              _variant = r;
                                              if (!_canSpice) {
                                                _isSpiced = false;
                                              }
                                              if (!_ginsengEnabled) {
                                                _ginsengGrams = 0;
                                              }
                                            });
                                          },
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    side: BorderSide(
                                      color: disabled
                                          ? Colors.grey.shade300
                                          : Colors.brown.shade200,
                                    ),
                                    selectedColor: disabled
                                        ? Colors.grey.shade200
                                        : Colors.brown.shade100,
                                    backgroundColor: disabled
                                        ? Colors.grey.shade100
                                        : null,
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // === ????? (?? ????) ===
                          Row(
                            children: [
                              Expanded(
                                child: ToggleCard(
                                  title: AppStrings.labelHospitality,
                                  value: _isComplimentary,
                                  busy: _busy,
                                  onChanged: (v) =>
                                      setState(() => _isComplimentary = v),
                                  leadingIcon: Icons.card_giftcard,
                                ),
                              ),
                              if (_canSpice) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ToggleCard(
                                    title: AppStrings.labelSpiced,
                                    value: _isSpiced,
                                    busy: _busy,
                                    onChanged: (v) =>
                                        setState(() => _isSpiced = v),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),

                          // === ?????? (??? ?? canSpice) ===
                          _ginsengCard(),
                          if (_ginsengEnabled) const SizedBox(height: 12),

                          // ??? ???????
                          Align(
                            alignment: Alignment.center,
                            child: SegmentedButton<InputMode>(
                              segments: const [
                                ButtonSegment(
                                  value: InputMode.grams,
                                  label: Text(AppStrings.labelInputByGrams),
                                  icon: Icon(Icons.scale),
                                ),
                                ButtonSegment(
                                  value: InputMode.price,
                                  label: Text(AppStrings.labelInputByPrice),
                                  icon: Icon(Icons.attach_money),
                                ),
                              ],
                              selected: {_mode},
                              onSelectionChanged: _busy
                                  ? null
                                  : (s) => setState(() {
                                      _mode = s.first;
                                      if (_showPad) {
                                        if (_padTarget == _PadTarget.price &&
                                            _mode != InputMode.price) {
                                          _closePad();
                                        }
                                        if (_padTarget == _PadTarget.grams &&
                                            _mode != InputMode.grams) {
                                          _closePad();
                                        }
                                      }
                                    }),
                              showSelectedIcon: false,
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (_mode == InputMode.grams) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                children: [
                                  const Text(AppStrings.labelQuantityGrams),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _gramsCtrl,
                                      readOnly: true,
                                      textAlign: TextAlign.center,
                                      onTap: _busy
                                          ? null
                                          : () => _openPad(_PadTarget.grams),
                                      decoration: const InputDecoration(
                                        hintText: AppStrings.hintExample250,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 10,
                                        ),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                children: [
                                  const Text(AppStrings.labelAmountLep),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _priceCtrl,
                                      readOnly: true,
                                      textAlign: TextAlign.center,
                                      onTap: _busy
                                          ? null
                                          : () => _openPad(_PadTarget.price),
                                      decoration: const InputDecoration(
                                        hintText: AppStrings.hintExample120,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 10,
                                        ),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(AppStrings.labelCalculatedGrams),
                                const Spacer(),
                                Text(
                                  AppStrings.calculatedGramsLine(
                                    _gramsEffective,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),
                          _KVRow(
                            k: AppStrings.labelPricePerKg,
                            v: _sellPerKg,
                            suffix: AppStrings.labelGramsShort,
                          ),
                          _KVRow(
                            k: AppStrings.labelPricePerGram,
                            v: _pricePerG,
                            suffix: AppStrings.labelGramsShort,
                          ),
                          const SizedBox(height: 8),

                          // ????????
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.brown.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.brown.shade100),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  AppStrings.labelInvoiceTotal,
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
                            _WarningBox(text: _fatal!),
                          ],

                          // ????????
                          AnimatedSize(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOut,
                            child: _showPad
                                ? _numPad(
                                    allowDot: _padTarget == _PadTarget.price,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: DialogActionRow(
                        busy: _busy,
                        onCancel: () => Navigator.pop(context),
                        onConfirm: _commitSale,
                        onConfirmLongPress:
                            _canQuickConfirm ? _commitInstantInvoice : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
