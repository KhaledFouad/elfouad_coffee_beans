import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sale_component.dart';
import '../models/sale_record.dart';
import '../viewmodels/sales_history_view_model.dart';
import '../utils/sale_utils.dart';

class SaleTile extends StatelessWidget {
  const SaleTile({super.key, required this.record});

  final SaleRecord record;

  @override
  Widget build(BuildContext context) {
    final isDeferredUnpaid = record.isDeferred && !record.isPaid;
    final theme = Theme.of(context);
    final tileBackground = isDeferredUnpaid
        ? deferredTileColor(record.note)
        : theme.colorScheme.surface;
    final borderColor = isDeferredUnpaid
        ? deferredBorderColor(record.note)
        : theme.dividerColor.withValues(alpha: 0.1);

    final tile = ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      collapsedBackgroundColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isDeferredUnpaid
            ? deferredBaseColor(record.note)
            : Colors.brown.shade100,
        child: Icon(
          _iconForType(record.type),
          color: Colors.brown.shade700,
          size: 18,
        ),
      ),
      title: _TitleRow(record: record),
      subtitle: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [_KeyValue(label: 'الإجمالي', value: record.totalPrice)],
      ),
      children: [
        if (record.components.isEmpty)
          const ListTile(title: Text('— لا توجد تفاصيل مكونات —'))
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: record.components
                  .map((component) => _ComponentRow(component: component))
                  .toList(),
            ),
          ),
        if (record.usesSettledTime)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              bottom: 8,
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 16, color: Colors.brown),
                const SizedBox(width: 6),
                Text(
                  'التاريخ الأصلي: ${record.originalDateTimeLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (record.canSettle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _SettleButton(record: record),
            ),
          ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tileBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isDeferredUnpaid ? 1.2 : 0.4,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: tile,
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.record});

  final SaleRecord record;

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(fontWeight: FontWeight.w700);
    final timeStyle = const TextStyle(fontSize: 12, color: Colors.black54);

    return Row(
      children: [
        Expanded(
          child: Text(
            record.titleLine,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (record.isComplimentary) ...[
          const SizedBox(width: 6),
          _Chip(
            label: 'ضيافة',
            border: Colors.orange.shade200,
            fill: Colors.orange.shade50,
          ),
        ],
        if (record.isDeferred && !record.isPaid) ...[
          const SizedBox(width: 6),
          DeferredBadge(note: record.note),
        ],
        if (record.isDeferred && record.isPaid) ...[
          const SizedBox(width: 6),
          _Chip(
            label: 'مدفوع',
            border: Colors.green.shade200,
            fill: Colors.green.shade50,
          ),
        ],
        const SizedBox(width: 6),
        Text(record.displayTime, style: timeStyle),
      ],
    );
  }
}

class DeferredBadge extends StatelessWidget {
  const DeferredBadge({super.key, required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final background = deferredTileColor(note);
    final border = deferredBorderColor(note);
    final textColor = deferredTextColor(note);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color.lerp(background, Colors.white, 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'أجل :   ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                note,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: textColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.border, required this.fill});

  final String label;
  final Color border;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(color: Colors.black54)),
        Text(
          value.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});

  final SaleComponent component;

  @override
  Widget build(BuildContext context) {
    final label = component.label;
    final quantity = component.quantityLabel(normalizeUnit);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const Icon(Icons.circle, size: 8),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (quantity.isNotEmpty)
            Text(quantity, style: const TextStyle(color: Colors.black54)),
          const SizedBox(width: 12),
          Text(
            'س:${component.lineTotalPrice.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SettleButton extends StatelessWidget {
  const _SettleButton({required this.record});

  final SaleRecord record;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(const Color(0xFF543824)),
      ),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تأكيد السداد'),
            content: Text(
              'سيتم تثبيت دفع ${record.totalPrice.toStringAsFixed(2)} جم.\nهل تريد المتابعة؟',
            ),
            actions: [
              TextButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    const Color.fromARGB(255, 242, 240, 240),
                  ),
                  foregroundColor: WidgetStateProperty.all(Colors.brown),
                  overlayColor: WidgetStateProperty.all(Colors.brown.shade50),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.brown),
                ),
              ),
              FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    const Color(0xFF543824),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تأكيد'),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          final messenger = ScaffoldMessenger.of(context);
          final viewModel = context.read<SalesHistoryViewModel>();
          try {
            await viewModel.settleDeferredSale(record.id);
            messenger.showSnackBar(
              const SnackBar(content: Text('تم تسوية العملية المؤجّلة')),
            );
          } catch (error) {
            messenger.showSnackBar(
              SnackBar(content: Text('تعذر التسوية: $error')),
            );
          }
        }
      },
      icon: const Icon(Icons.payments),
      label: const Text('تم الدفع'),
    );
  }
}

IconData _iconForType(String type) {
  switch (type) {
    case 'drink':
      return Icons.local_cafe;
    case 'single':
      return Icons.coffee_outlined;
    case 'ready_blend':
      return Icons.blender_outlined;
    case 'custom_blend':
      return Icons.auto_awesome_mosaic;
    case 'extra':
      return Icons.cookie_rounded;
    default:
      return Icons.receipt_long;
  }
}
