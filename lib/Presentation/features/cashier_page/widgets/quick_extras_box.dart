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
              if (snap.hasError)
                return Text('تعذر تحميل $title: ${snap.error}');
              final items = snap.data ?? const <ExtraItem>[];
              if (items.isEmpty) return Text('لا يوجد $title متاح حالياً');

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
    final ctrl = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item.name),
        content: TextField(
          controller: ctrl,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(),
          decoration: const InputDecoration(labelText: 'الكمية (قطع)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('بيع'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final q = int.tryParse(ctrl.text.trim()) ?? 1;
    try {
      await sellExtra(extraId: item.id, qty: q);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم بيع $q × ${item.name}')));
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل البيع: $e')));
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
              '${item.priceSell.toStringAsFixed(2)} ج/قطعة',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'مخزون: ${item.stockUnits}',
              style: TextStyle(color: Colors.brown.shade700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
