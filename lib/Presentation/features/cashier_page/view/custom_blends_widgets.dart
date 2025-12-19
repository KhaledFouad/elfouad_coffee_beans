part of 'custom_blends_page.dart';

/// ====== Blend line card ======
class _LineCard extends StatelessWidget {
  final List<SingleVariantItem> items; // Singles + Blends
  final _BlendLine line;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  final VoidCallback onTapGrams;
  final VoidCallback onTapPrice;

  const _LineCard({
    required this.items,
    required this.line,
    required this.onChanged,
    required this.onTapGrams,
    required this.onTapPrice,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isWide =
        MediaQuery.of(context).size.width >= AppBreakpoints.compactWidth;

    final dropdown = DropdownButtonFormField<SingleVariantItem>(
      isExpanded: true,
      initialValue: line.item,
      items: items.map((it) {
        final outOfStock = it.stock <= 0;
        final prefix =
            it.source == ItemSource.blends ? AppStrings.labelBlendPrefix : '';
        return DropdownMenuItem<SingleVariantItem>(
          value: it,
          enabled: !outOfStock,
          child: Text(
            outOfStock
                ? '$prefix${it.fullLabel} (${AppStrings.labelUnavailable})'
                : '$prefix${it.fullLabel}',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: outOfStock ? Colors.grey : null,
              decoration:
                  outOfStock ? TextDecoration.lineThrough : TextDecoration.none,
              decorationThickness: outOfStock ? 1 : 0,
            ),
          ),
        );
      }).toList(),
      selectedItemBuilder: (ctx) => items.map((it) {
        final outOfStock = it.stock <= 0;
        final prefix =
            it.source == ItemSource.blends ? AppStrings.labelBlendPrefix : '';
        return Align(
          alignment: Alignment.centerRight,
          child: Text(
            outOfStock
                ? '$prefix${it.fullLabel} (${AppStrings.labelUnavailable})'
                : '$prefix${it.fullLabel}',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: outOfStock ? Colors.grey : null,
              decoration:
                  outOfStock ? TextDecoration.lineThrough : TextDecoration.none,
              decorationThickness: outOfStock ? 1 : 0,
            ),
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v == null || v.stock <= 0) return;
        line.item = v;
        onChanged();
      },
      decoration: const InputDecoration(
        labelText: AppStrings.labelBlendComponentName,
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );

    // Grams input (readOnly + keypad entry)
    final gramField = TextFormField(
      readOnly: true,
      controller: TextEditingController(
        text: line.mode == LineInputMode.grams && line.grams > 0
            ? '${line.grams}'
            : '',
      ),
      onTap: onTapGrams,
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        labelText: AppStrings.labelQuantityGrams,
        hintText: AppStrings.hintExample250,
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );

    // Price input (readOnly + keypad entry)
    final priceField = TextFormField(
      readOnly: true,
      controller: TextEditingController(
        text: line.mode == LineInputMode.price && line.price > 0
            ? line.price.toStringAsFixed(2)
            : '',
      ),
      onTap: onTapPrice,
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        labelText: AppStrings.labelAmountLep,
        hintText: AppStrings.hintExample120,
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );

    Widget sideBox() {
      if (line.mode == LineInputMode.grams) {
        return _KVBox(
          title: AppStrings.labelPrice,
          value: line.linePrice,
          suffix: AppStrings.labelGramsShort,
          fractionDigits: 2,
        );
      } else {
        return _KVBox(
          title: AppStrings.labelGrams,
          value: line.gramsEffective.toDouble(),
          suffix: AppStrings.labelGramsShort,
          fractionDigits: 0,
        );
      }
    }

    final modeAndField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<LineInputMode>(
          segments: const [
            ButtonSegment(
              value: LineInputMode.grams,
              label: Text(AppStrings.labelGrams),
              icon: Icon(Icons.scale),
            ),
            ButtonSegment(
              value: LineInputMode.price,
              label: Text(AppStrings.labelPrice),
              icon: Icon(Icons.attach_money),
            ),
          ],
          selected: {line.mode},
          onSelectionChanged: (s) {
            line.mode = s.first;
            onChanged();
          },
          showSelectedIcon: false,
        ),
        const SizedBox(height: 8),
        if (line.mode == LineInputMode.grams) gramField else priceField,
        if (line.mode == LineInputMode.price) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              AppStrings.calculatedGramsLine(line.gramsEffective),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );

    final removeBtn = IconButton(
      tooltip: AppStrings.tooltipDelete,
      onPressed: onRemove,
      icon: const Icon(Icons.delete_outline),
    );

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: dropdown),
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: modeAndField),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: sideBox()),
                  const SizedBox(width: 8),
                  removeBtn,
                ],
              )
            : Column(
                children: [
                  dropdown,
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: modeAndField),
                      const SizedBox(width: 8),
                      Expanded(flex: 4, child: sideBox()),
                    ],
                  ),
                  Align(alignment: Alignment.centerLeft, child: removeBtn),
                ],
              ),
      ),
    );
  }
}

class _KVBox extends StatelessWidget {
  final String title;
  final double value;
  final String? suffix;
  final int fractionDigits;

  const _KVBox({
    required this.title,
    required this.value,
    this.suffix,
    this.fractionDigits = 2,
  });

  @override
  Widget build(BuildContext context) {
    final vText =
        value.toStringAsFixed(fractionDigits) +
        (suffix != null ? ' $suffix' : '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Text(vText, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final bool isComplimentary;
  final ValueChanged<bool?>? onComplimentaryChanged;

  final bool isDeferred;
  final ValueChanged<bool?>? onDeferredChanged;

  final bool isSpiced;
  final ValueChanged<bool?>? onSpicedChanged;

  final TextEditingController titleController;
  final bool titleEnabled;

  final int ginsengGrams;
  final VoidCallback? onGinsengMinus;
  final VoidCallback? onGinsengPlus;

  final int totalGrams;
  final double beansAmount;
  final double spiceAmount;
  final double ginsengAmount;
  final double totalPrice;
  final TextEditingController noteController;
  final bool noteVisible;
  final bool noteEnabled;

  const _TotalsCard({
    required this.isComplimentary,
    required this.onComplimentaryChanged,
    required this.isDeferred,
    required this.onDeferredChanged,
    required this.isSpiced,
    required this.onSpicedChanged,
    required this.titleController,
    required this.titleEnabled,
    required this.ginsengGrams,
    required this.onGinsengMinus,
    required this.onGinsengPlus,
    required this.totalGrams,
    required this.beansAmount,
    required this.spiceAmount,
    required this.ginsengAmount,
    required this.totalPrice,
    required this.noteController,
    required this.noteVisible,
    required this.noteEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DeferredNoteField(
              controller: titleController,
              visible: true,
              enabled: titleEnabled,
              label: AppStrings.labelCustomBlendTitle,
              hint: AppStrings.hintCustomBlendTitle,
              minLines: 1,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            // Complimentary + deferred options.
            Row(
              children: [
                Expanded(
                  child: ToggleCard(
                    title: AppStrings.labelHospitality,
                    value: isComplimentary,
                    onChanged: (v) => onComplimentaryChanged?.call(v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ToggleCard(
                    title: AppStrings.btnDefer,
                    value: isDeferred,
                    onChanged: (v) => onDeferredChanged?.call(v),
                  ),
                ),
              ],
            ),
            DeferredNoteField(
              controller: noteController,
              visible: noteVisible,
              enabled: noteEnabled,
            ),
            const SizedBox(height: 12),
            // Spiced toggle.
            ToggleCard(
              title: AppStrings.labelSpiced,
              value: isSpiced,
              onChanged: (v) => onSpicedChanged?.call(v),
            ),

            // Ginseng row.
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.brown.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.brown.shade100),
              ),
              child: Row(
                children: [
                  const Text(
                    AppStrings.labelGinseng,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: onGinsengMinus,
                    icon: const Icon(Icons.remove),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '$ginsengGrams ${AppStrings.labelGramsShort}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: onGinsengPlus,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            _row(
              AppStrings.labelTotalGrams,
              '$totalGrams ${AppStrings.labelGramsShort}',
            ),
            const SizedBox(height: 6),
            _row(AppStrings.labelBeansAmount, beansAmount.toStringAsFixed(2)),
            _row(AppStrings.labelSpiceAmount, spiceAmount.toStringAsFixed(2)),
            _row(
              AppStrings.labelGinsengAmount,
              ginsengAmount.toStringAsFixed(2),
            ),
            const Divider(height: 18),
            _row(AppStrings.labelInvoiceTotal, totalPrice.toStringAsFixed(2)),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Row(
      children: [
        Text(k),
        const Spacer(),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _WarningBox extends StatelessWidget {
  final String text;
  const _WarningBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
}
