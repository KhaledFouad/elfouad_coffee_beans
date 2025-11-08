import 'package:elfouad_coffee_beans/core/services/extras_repo.dart'
    show sellExtra, extrasStreamByCategory;
import 'package:elfouad_coffee_beans/data/models/extra_item.dart'
    show ExtraItem;
import 'package:flutter/material.dart';

class QuickExtrasBox extends StatelessWidget {
  final String title;
  final String category;

  const QuickExtrasBox({
    super.key,
    required this.title,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: StreamBuilder<List<ExtraItem>>(
            stream: extrasStreamByCategory(category),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Text('Error loading $title: ${snap.error}');
              }
              final items = snap.data ?? const <ExtraItem>[];
              if (items.isEmpty) {
                return const Text('No quick extras available right now.');
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _ItemTile(item: items[i]),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final ExtraItem item;
  const _ItemTile({required this.item});

  Future<void> _askAndSell(BuildContext context) async {
    final controller = TextEditingController(text: '1');
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(item.name),
          content: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(),
            decoration: const InputDecoration(labelText: 'Quantity (pieces)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sell'),
            ),
          ],
        ),
      );

      if (!context.mounted || confirmed != true) return;

      final qty = int.tryParse(controller.text.trim()) ?? 1;
      await sellExtra(extraId: item.id, qty: qty);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sold $qty x ${item.name}')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sell item: $error')),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _askAndSell(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.brown.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${item.priceSell.toStringAsFixed(2)} EGP / unit',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Stock: ${item.stockUnits}',
              style: TextStyle(color: Colors.brown.shade700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
