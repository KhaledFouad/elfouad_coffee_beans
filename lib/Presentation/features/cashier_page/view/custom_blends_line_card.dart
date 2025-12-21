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
