part of 'custom_blends_page.dart';

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
