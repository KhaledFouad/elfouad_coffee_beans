part of 'drink_dialog.dart';

mixin _DrinkDialogBuild on _DrinkDialogStateBase {
  Widget _buildDialog(BuildContext context) {
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
                    DialogImageHeader(image: _image, title: _name),

                    // Body
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (_variantOptions.isNotEmpty) ...[
                            Align(
                              alignment: Alignment.center,
                              child: SegmentedButton<String>(
                                segments: _variantOptions
                                    .map(
                                      (v) => ButtonSegment(
                                        value: v,
                                        label: Text(v),
                                      ),
                                    )
                                    .toList(),
                                selected: {_variant},
                                onSelectionChanged: _busy
                                    ? null
                                    : (s) => setState(() => _variant = s.first),
                                showSelectedIcon: false,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          if (_showLegacyServing) ...[
                            Align(
                              alignment: Alignment.center,
                              child: SegmentedButton<Serving>(
                                segments: const [
                                  ButtonSegment(
                                    value: Serving.single,
                                    label: Text(AppStrings.labelSingles),
                                    icon: Icon(Icons.coffee_outlined),
                                  ),
                                  ButtonSegment(
                                    value: Serving.dbl,
                                    label: Text(AppStrings.labelDouble),
                                    icon: Icon(Icons.coffee),
                                  ),
                                ],
                                selected: {_serving},
                                onSelectionChanged: _busy
                                    ? null
                                    : (s) => setState(() => _serving = s.first),
                                showSelectedIcon: false,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          if (_showLegacyMix) ...[
                            Align(
                              alignment: Alignment.center,
                              child: SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'water',
                                    label: Text(AppStrings.labelWater),
                                    icon: Icon(Icons.water_drop_outlined),
                                  ),
                                  ButtonSegment(
                                    value: 'milk',
                                    label: Text(AppStrings.labelMilk),
                                    icon: Icon(Icons.local_drink),
                                  ),
                                ],
                                selected: {_mix},
                                onSelectionChanged: _busy
                                    ? null
                                    : (s) => setState(() => _mix = s.first),
                                showSelectedIcon: false,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          if (_roastOptions.isNotEmpty) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _roastOptions.map((r) {
                                  final label =
                                      r.isEmpty ? AppStrings.labelNone : r;
                                  final selected = _roast == r;
                                  return ChoiceChip(
                                    label: Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    selected: selected,
                                    onSelected: _busy
                                        ? null
                                        : (v) {
                                            if (!v) return;
                                            setState(() => _roast = r);
                                          },
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    side: BorderSide(
                                      color: Colors.brown.shade200,
                                    ),
                                    selectedColor: Colors.brown.shade100,
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // === Toggles row (????? ??? ??????) ===
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
                              if (_spicedEnabled) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ToggleCard(
                                    title: AppStrings.labelSpiced,
                                    value: _spiced,
                                    busy: _busy,
                                    onChanged: (v) =>
                                        setState(() => _spiced = v),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ??? ?????
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                AppStrings.labelCupPrice,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${_displayUnitPrice.toStringAsFixed(2)} ${AppStrings.labelGramsShort}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Quantity stepper
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

                          // ?????? ?????
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                AppStrings.dialogCancel,
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
                                      AppStrings.dialogConfirm,
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
    );
  }
}

