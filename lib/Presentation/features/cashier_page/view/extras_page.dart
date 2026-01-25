// extras_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/extra_dialog.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_breakpoints.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

class ExtrasPage extends StatelessWidget {
  const ExtrasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final titleSize =
        ResponsiveValue<double>(
          context,
          defaultValue: 35,
          conditionalValues: const [
            Condition.smallerThan(name: TABLET, value: 24),
            Condition.between(start: AppBreakpoints.tabletStart, end: AppBreakpoints.tabletEnd, value: 30),
          ],
        ).value;

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
              tooltip: AppStrings.tooltipBack,
            ),
            title: Text(
              AppStrings.titleCookiesSection,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: titleSize,
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
            .orderBy('posOrder')
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
            return const Center(child: Text(AppStrings.errorLoadingCookies));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text(AppStrings.emptyCookies));
          }

          late final List<_ExtraItem> items;
          try {
            items = snap.data!.docs.map((doc) {
              final data = doc.data();
              final name = (data['name'] ?? '').toString();
              final image = (data['image'] ?? 'assets/cookies.png').toString();

              double numValue(v) => (v is num)
                  ? v.toDouble()
                  : double.tryParse('${v ?? ''}') ?? 0.0;
              int intValue(v) =>
                  (v is num) ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
              int posOrderValue(v) =>
                  (v is num) ? v.toInt() : int.tryParse('${v ?? ''}') ?? 999999;

              final priceSell = numValue(data['price_sell']);
              final costUnit = numValue(data['cost_unit']);
              final stock = intValue(data['stock_units']);
              final variant = (data['variant'] as String?)?.trim();
              final posOrder = posOrderValue(data['posOrder']);

              return _ExtraItem(
                id: doc.id,
                name: name,
                image: image,
                priceSell: priceSell,
                costUnit: costUnit,
                stockUnits: stock,
                variant: variant,
                posOrder: posOrder,
                raw: data,
              );
            }).toList();

            items.sort((a, b) {
              final order = a.posOrder.compareTo(b.posOrder);
              if (order != 0) return order;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
          } catch (e, st) {
            logError(e, st);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) showErrorDialog(context, e, st);
            });
            return const Center(child: Text(AppStrings.errorReadingItems));
          }

          return LayoutBuilder(
            builder: (context, c) {
              final max = c.maxWidth;
              final crossAxisCount = AppBreakpoints.gridCount(max);
              const spacing = 16.0;

              return GridView.builder(
                padding: AppBreakpoints.gridPagePadding(max),
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
  final int posOrder;
  final Map<String, dynamic> raw;
  _ExtraItem({
    required this.id,
    required this.name,
    required this.image,
    required this.priceSell,
    required this.costUnit,
    required this.stockUnits,
    required this.variant,
    required this.posOrder,
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
    final titleSize =
        ResponsiveValue<double>(
          context,
          defaultValue: 30,
          conditionalValues: const [
            Condition.smallerThan(name: TABLET, value: 22),
            Condition.between(start: AppBreakpoints.tabletStart, end: AppBreakpoints.tabletEnd, value: 26),
          ],
        ).value;

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
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.60),
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
                  color: Colors.black.withValues(alpha: 0.40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
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
          Text(
            '${AppStrings.labelUnitPricePiece} ${item.priceSell.toStringAsFixed(2)} ج',
          ),
          const SizedBox(height: 8),
          Text(AppStrings.stockPiecesAr(item.stockUnits)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(),
            decoration: const InputDecoration(
              labelText: AppStrings.labelQuantityPieces,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(AppStrings.dialogCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(AppStrings.btnSellAr),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (ok != true) return;

  final qty = int.tryParse(ctrl.text.trim()) ?? 1;
  await _sellExtraTransaction(context, item.id, qty);
  if (!context.mounted) return;
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

      double numValue(v) =>
          (v is num) ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;
      int intValue(v) =>
          (v is num) ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

      final name = (data['name'] ?? '').toString();
      final variant = (data['variant'] as String?)?.trim();
      final priceSell = numValue(data['price_sell']);
      final costUnit = numValue(data['cost_unit']);
      final stockUnits = intValue(data['stock_units']);

      if (qty <= 0) throw AppStrings.errorInvalidQuantity;
      if (stockUnits < qty) {
        throw AppStrings.stockNotEnough(stockUnits, AppStrings.labelPieceUnit);
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


