// extras_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/ExtraDialog.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:flutter/material.dart';

class ExtrasPage extends StatelessWidget {
  const ExtrasPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ===== AppBar بنفس ستايل DrinksPage =====
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          child: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.maybePop(context),
              tooltip: 'رجوع',
            ),
            title: const Text(
              'بسكوت ومعمول',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 35,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
            elevation: 8,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5D4037), Color(0xFF795548)],
                ),
              ),
            ),
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // بنجيب عناصر biscuits فقط (حسب الـ seed اللي بعته)
        stream: FirebaseFirestore.instance
            .collection('extras')
            .where('category', isEqualTo: 'biscuits')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final e = snap.error!;
            logError(e, snap.stackTrace);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) showErrorDialog(context, e, snap.stackTrace);
            });
            return const Center(child: Text('حدث خطأ أثناء تحميل الأصناف'));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('لا يوجد أصناف (بسكوت/معمول)'));
          }

          late final List<_ExtraItem> items;
          try {
            items = snap.data!.docs.map((doc) {
              final data = doc.data();
              final name = (data['name'] ?? '').toString();
              final image = (data['image'] ?? 'assets/cookies.png').toString();

              double _num(v) => (v is num)
                  ? v.toDouble()
                  : double.tryParse('${v ?? ''}') ?? 0.0;
              int _int(v) =>
                  (v is num) ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

              final priceSell = _num(data['price_sell']);
              final costUnit = _num(data['cost_unit']);
              final stock = _int(data['stock_units']);
              final variant = (data['variant'] as String?)?.trim();

              return _ExtraItem(
                id: doc.id,
                name: name,
                image: image,
                priceSell: priceSell,
                costUnit: costUnit,
                stockUnits: stock,
                variant: variant,
                raw: data,
              );
            }).toList();

            // === ترتيب مخصص: حسب أصنافك، ثم أبجديًا ===
            const preferredOrderExtras = <String>[
              'تمر دارك شوكلت',
              'تمر وايت شوكلت',
              'معمول سادة',
              'معمول تمر',
              'معمول قرفة',
              'معمول وايت شوكلت',
              'معمول دارك شوكلت',
            ];
            final rank = <String, int>{
              for (var i = 0; i < preferredOrderExtras.length; i++)
                preferredOrderExtras[i]: i,
            };
            items.sort((a, b) {
              final ra = rank[a.name] ?? 1 << 20;
              final rb = rank[b.name] ?? 1 << 20;
              if (ra != rb) return ra.compareTo(rb);
              return a.name.compareTo(b.name);
            });
            // === نهاية الترتيب ===
          } catch (e, st) {
            logError(e, st);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) showErrorDialog(context, e, st);
            });
            return const Center(child: Text('تعذر قراءة بيانات الأصناف'));
          }

          return LayoutBuilder(
            builder: (context, c) {
              final max = c.maxWidth;
              final crossAxisCount = max >= 1200
                  ? 4
                  : max >= 900
                  ? 3
                  : max >= 600
                  ? 2
                  : 1;
              const spacing = 16.0;

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: 1.25,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final it = items[i];
                  return _ExtraCard(
                    title: it.name,
                    image: it.image,
                    subtitle:
                        'سعر: ${it.priceSell.toStringAsFixed(2)} ج / قطعة • مخزون: ${it.stockUnits}',
                    onTap: () async {
                      try {
                        await showDialog(
                          context: context,
                          builder: (_) => ExtraDialog(
                            extraId: it.id,
                            extraData: it.raw, // نفس الماب اللي قريتها
                          ),
                        );
                      } catch (e, st) {
                        logError(e, st);
                        if (context.mounted) {
                          await showErrorDialog(context, e, st);
                        }
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ExtraItem {
  final String id;
  final String name;
  final String image;
  final double priceSell;
  final double costUnit;
  final int stockUnits;
  final String? variant;
  final Map<String, dynamic> raw;
  _ExtraItem({
    required this.id,
    required this.name,
    required this.image,
    required this.priceSell,
    required this.costUnit,
    required this.stockUnits,
    required this.variant,
    required this.raw,
  });
}

class _ExtraCard extends StatelessWidget {
  final String title;
  final String image;
  final String subtitle;
  final VoidCallback onTap;
  const _ExtraCard({
    required this.title,
    required this.image,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.grey.shade300),
            ),
            // طبقة تغميق خفيفة
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.60),
                  ],
                ),
              ),
            ),
            // العنوان + سطر معلومات صغير
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black45,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    // const SizedBox(height: 6),
                    // Text(
                    //   subtitle,
                    //   textAlign: TextAlign.center,
                    //   style: const TextStyle(
                    //     color: Colors.white70,
                    //     fontSize: 13,
                    //     fontWeight: FontWeight.w600,
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog بسيط لاختيار كمية وبيع بالقطعة
Future<void> _showSellDialog(BuildContext context, _ExtraItem item) async {
  final ctrl = TextEditingController(text: '1');
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(item.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('سعر القطعة: ${item.priceSell.toStringAsFixed(2)} ج'),
          const SizedBox(height: 8),
          Text('المخزون الحالي: ${item.stockUnits} قطعة'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(),
            decoration: const InputDecoration(
              labelText: 'الكمية (قطع)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
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

  final qty = int.tryParse(ctrl.text.trim()) ?? 1;
  await _sellExtraTransaction(context, item.id, qty);
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('تم بيع $qty × ${item.name}')));
}

/// بيع + خصم مخزون + تسجيل في sales (ترانزاكشن)
Future<void> _sellExtraTransaction(
  BuildContext context,
  String extraId,
  int qty,
) async {
  final db = FirebaseFirestore.instance;
  final ref = db.collection('extras').doc(extraId);

  try {
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw 'الصنف غير موجود';
      final data = snap.data() ?? {};

      double _num(v) =>
          (v is num) ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;
      int _int(v) => (v is num) ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

      final name = (data['name'] ?? '').toString();
      final variant = (data['variant'] as String?)?.trim();
      final priceSell = _num(data['price_sell']);
      final costUnit = _num(data['cost_unit']);
      final stockUnits = _int(data['stock_units']);

      if (qty <= 0) throw 'كمية غير صالحة';
      if (stockUnits < qty) {
        throw 'المخزون غير كافٍ: المتاح $stockUnits قطعة';
      }

      final totalPrice = priceSell * qty;
      final totalCost = costUnit * qty;
      final profit = totalPrice - totalCost;

      // خصم المخزون
      tx.update(ref, {
        'stock_units': stockUnits - qty,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // إنشاء عملية بيع في sales
      final saleRef = db.collection('sales').doc();
      tx.set(saleRef, {
        'type': 'extra',
        'source': 'extras',
        'extra_id': extraId,
        'name': name,
        'variant': variant,
        'unit': 'piece',
        'quantity': qty,
        'unit_price': priceSell,
        'total_price': totalPrice,
        'total_cost': totalCost,
        'profit_total': profit,
        'is_deferred': false,
        'paid': true,
        'payment_method': 'cash',
        'created_at': FieldValue.serverTimestamp(),
      });
    });
  } catch (e, st) {
    logError(e, st);
    // إظهار رسالة مفهومة للمستخدم
    if (context.mounted) {
      await showErrorDialog(context, e, st);
    }
    rethrow;
  }
}
