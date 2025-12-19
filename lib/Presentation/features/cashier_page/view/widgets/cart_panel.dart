import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/bloc/cart_cubit.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/deferred_note_field.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/toggle_card.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({
    super.key,
    required this.noteCtrl,
    required this.checkingOut,
    required this.onCheckout,
  });

  final TextEditingController noteCtrl;
  final bool checkingOut;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartCubit>().cart;
    final lines = cart.lines;
    final totalPrice = cart.totalPrice;
    final isDeferred = cart.invoiceDeferred;
    final isComplimentary = cart.invoiceComplimentary;
    final isEmpty = lines.isEmpty;
    final displayTotal = isComplimentary ? 0.0 : totalPrice;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useOuterScroll = constraints.maxHeight < 520;

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              AppStrings.titleCart,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: lines.isEmpty
                  ? const Center(
                      child: Text(AppStrings.cartEmptyAddProductsToContinue),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: lines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final line = lines[i];
                        final qtyLabel = line.grams > 0
                            ? '${line.grams.toStringAsFixed(0)} ${AppStrings.labelGramsShort}'
                            : '${line.quantity.toStringAsFixed(2)} ${line.unit}';

                        return Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(
                              vertical: -1,
                              horizontal: -1,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.brown.shade50,
                              child: Text(
                                line.name.isNotEmpty ? line.name[0] : '#',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF543824),
                                ),
                              ),
                            ),
                            title: Text(
                              line.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              line.variant?.isNotEmpty == true
                                  ? '${line.variant!} - $qtyLabel'
                                  : qtyLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  (isComplimentary || line.isComplimentary
                                          ? 0.0
                                          : line.lineTotalPrice)
                                      .toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF543824),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: const VisualDensity(
                                    vertical: -4,
                                    horizontal: -4,
                                  ),
                                  onPressed: () => context
                                      .read<CartCubit>()
                                      .removeLine(line.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isStacked = constraints.maxWidth < 320;
                final complimentary = ToggleCard(
                  title: AppStrings.labelHospitality,
                  value: isComplimentary,
                  onChanged: (v) =>
                      context.read<CartCubit>().setInvoiceComplimentary(v),
                  leadingIcon: Icons.card_giftcard,
                );
                final deferred = ToggleCard(
                  title: AppStrings.labelDeferredInvoice,
                  value: isDeferred,
                  onChanged: (v) =>
                      context.read<CartCubit>().setInvoiceDeferred(v),
                  leadingIcon: Icons.schedule,
                );

                if (isStacked) {
                  return Column(
                    children: [
                      complimentary,
                      const SizedBox(height: 8),
                      deferred,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: complimentary),
                    const SizedBox(width: 10),
                    Expanded(child: deferred),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            DeferredNoteField(
              controller: noteCtrl,
              visible: true,
              enabled: isDeferred && !checkingOut,
            ),
            const SizedBox(height: 10),
            _summaryRow(AppStrings.labelInvoiceTotal, displayTotal),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    const Color(0xFF543824),
                  ),
                ),
                onPressed: (checkingOut || isEmpty) ? null : onCheckout,
                child: checkingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        AppStrings.btnCheckoutInvoice,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        );

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                blurRadius: 12,
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: useOuterScroll
              ? SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: content,
                  ),
                )
              : content,
        );
      },
    );
  }

  Widget _summaryRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value.toStringAsFixed(2)),
        ],
      ),
    );
  }
}
