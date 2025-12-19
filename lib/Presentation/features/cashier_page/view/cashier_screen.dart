import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/view/custom_blends_page.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/blends_models.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/cart_state.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/singles_models.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/blend_dialog.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/drink_dialog.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/extra_dialog.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/single_dialog.dart';
import 'package:elfouad_coffee_beans/Presentation/features/sales/pages/sales_history_page.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CashierHome extends StatelessWidget {
  const CashierHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ChangeNotifierProvider(
        create: (_) => CartState(),
        child: const _PosShell(),
      ),
    );
  }
}

enum _Category { drinks, singles, blends, extras, custom }

class _PosShell extends StatefulWidget {
  const _PosShell();

  @override
  State<_PosShell> createState() => _PosShellState();
}

class _PosShellState extends State<_PosShell> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  _Category _selected = _Category.drinks;
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl.addListener(() {
      final cart = context.read<CartState>();
      cart.setInvoiceNote(_noteCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartState>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1200;
            final cartPanelWidth = isWide ? 360.0 : 320.0;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: _buildCatalog(cart),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: cartPanelWidth,
                  child: _CartPanel(
                    noteCtrl: _noteCtrl,
                    checkingOut: _checkingOut,
                    onCheckout: () => _checkout(cart),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    const items = [
      (_Category.drinks, AppStrings.titleDrinksSection, Icons.local_cafe),
      (_Category.singles, AppStrings.titleSinglesSection, Icons.coffee_outlined),
      (_Category.blends, AppStrings.titleBlendsSection, Icons.blender_outlined),
      (_Category.extras, AppStrings.titleCookiesSection, Icons.cookie),
      (_Category.custom, AppStrings.titleCustomBlendSection, Icons.auto_awesome_motion),
    ];

    // تكبير الابعاد شوية على التابلت
    final size = MediaQuery.of(context).size;
    final isTabletWidth = size.width >= 800;

    final sidebarWidth = isTabletWidth ? 240.0 : 200.0;
    final buttonHeight = isTabletWidth ? 72.0 : 60.0;
    final fontSize = isTabletWidth ? 18.0 : 16.0;
    final iconSize = isTabletWidth ? 24.0 : 22.0;

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            AppStrings.titleSections,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),

          // أزرار الأقسام
          ...items.map((item) {
            final selected = _selected == item.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: buttonHeight,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF543824)
                          : Colors.brown.shade100,
                      width: selected ? 2 : 1,
                    ),
                    backgroundColor: selected
                        ? const Color(0x15543824)
                        : Colors.white,
                    foregroundColor: const Color(0xFF543824),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => setState(() => _selected = item.$1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // النص في النص تقريبًا
                      Expanded(
                        child: Text(
                          item.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: fontSize,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(item.$3, size: iconSize),
                    ],
                  ),
                ),
              ),
            );
          }),

          const Spacer(),
          const Divider(),

          // زر "سجل المبيعات" بمساحة لمس أكبر شوية
          ListTile(
            dense: false,
            minVerticalPadding: 14,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.receipt_long, size: 26),
            title: const Text(
              AppStrings.titleSalesHistorySimple,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SalesHistoryPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          const Text(
            AppStrings.titlePos,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: AppStrings.hintSearchProduct,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (kIsWeb)
            IconButton(
              tooltip: AppStrings.tooltipRefresh,
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    );
  }

  Widget _buildCatalog(CartState cart) {
    switch (_selected) {
      case _Category.drinks:
        return _DrinksGrid(
          query: _searchCtrl.text,
          onAdd: (line) => _addLine(cart, line),
        );
      case _Category.singles:
        return _SinglesGrid(
          query: _searchCtrl.text,
          onAdd: (line) => _addLine(cart, line),
        );
      case _Category.blends:
        return _BlendsGrid(
          query: _searchCtrl.text,
          onAdd: (line) => _addLine(cart, line),
        );
      case _Category.extras:
        return _ExtrasGrid(
          query: _searchCtrl.text,
          onAdd: (line) => _addLine(cart, line),
        );
      case _Category.custom:
        return _CustomBlendEntry(onAdd: (line) => _addLine(cart, line));
    }
  }

  void _addLine(CartState cart, CartLine line) {
    cart.addLine(line);
    ScaffoldMessenger.of(context);
  }

  Future<void> _checkout(CartState cart) async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.cartEmptyAddProductsFirst)),
      );
      return;
    }
    setState(() => _checkingOut = true);
    try {
      await CartCheckout.commitInvoice(cart: cart);
      cart.clear();
      _noteCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context);
    } catch (e, st) {
      logError(e, st);
      if (mounted) await showErrorDialog(context, e, st);
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.noteCtrl,
    required this.checkingOut,
    required this.onCheckout,
  });

  final TextEditingController noteCtrl;
  final bool checkingOut;
  final VoidCallback onCheckout;

  @override
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final lines = cart.lines;
    final totalPrice = cart.totalPrice;
    final isDeferred = cart.invoiceDeferred;
    final isEmpty = lines.isEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        // If height is very small, allow scrolling of the whole panel.
        final useOuterScroll = constraints.maxHeight < 520;

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              AppStrings.titleCart,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            // ===== List of lines =====
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
                                  line.lineTotalPrice.toStringAsFixed(2),
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
                                      .read<CartState>()
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

            // ===== Deferred toggle + payment method (if any) =====
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Switch(
                        value: isDeferred,
                        onChanged: (v) =>
                            context.read<CartState>().setInvoiceDeferred(v),
                      ),
                      const SizedBox(width: 4),
                      const Flexible(
                        child: Text(
                          AppStrings.labelDeferredInvoice,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // if you later add payment method dropdown, put it here
              ],
            ),

            const SizedBox(height: 8),

            // ===== Note field =====
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: AppStrings.hintCustomerNoteOptional,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 10),

            _summaryRow(AppStrings.labelInvoiceTotal, totalPrice),

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

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CatalogItem {
  _CatalogItem({
    required this.title,
    required this.image,
    required this.onTap,
    this.subtitle,
    this.priceText,
  });

  final String title;
  final String image;
  final String? subtitle;
  final String? priceText;
  final VoidCallback onTap;
}

class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({required this.items});

  final List<_CatalogItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text(AppStrings.noMatchingItems));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final max = constraints.maxWidth;
        final cross = max >= 1200
            ? 4
            : max >= 900
            ? 3
            : max >= 600
            ? 2
            : 1;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _CatalogCard(item: items[i]),
        );
      },
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item});

  final _CatalogItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.asset(
                item.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: Colors.brown.shade50),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                  if (item.priceText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.priceText!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF543824),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrinksGrid extends StatelessWidget {
  const _DrinksGrid({required this.query, required this.onAdd});

  final String query;
  final ValueChanged<CartLine> onAdd;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('drinks').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text(AppStrings.errorLoadingDrinks));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text(AppStrings.emptyDrinks));
        }

        final q = query.trim().toLowerCase();
        final items =
            snap.data!.docs
                .map((doc) {
                  final data = doc.data();
                  final name = (data['name'] ?? '').toString();
                  final image = (data['image'] ?? 'assets/drinks.jpg')
                      .toString();
                  final sellPrice = (data['sellPrice'] is num)
                      ? (data['sellPrice'] as num).toDouble()
                      : double.tryParse('${data['sellPrice'] ?? 0}') ?? 0.0;
                  return (
                    id: doc.id,
                    name: name,
                    image: image,
                    price: sellPrice,
                    data: data,
                  );
                })
                .where((d) {
                  if (q.isEmpty) return true;
                  return d.name.toLowerCase().contains(q);
                })
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

        final cards = items
            .map(
              (it) => _CatalogItem(
                title: it.name,
                image: it.image,
                priceText: '${it.price.toStringAsFixed(2)} ج.م',
                onTap: () async {
                  try {
                    await showDialog(
                      context: context,
                      builder: (_) => DrinkDialog(
                        drinkId: it.id,
                        drinkData: it.data,
                        onAddToCart: onAdd,
                      ),
                    );
                  } catch (e, st) {
                    logError(e, st);
                    if (context.mounted) await showErrorDialog(context, e, st);
                  }
                },
              ),
            )
            .toList();

        return _CatalogGrid(items: cards);
      },
    );
  }
}

class _SinglesGrid extends StatelessWidget {
  const _SinglesGrid({required this.query, required this.onAdd});

  final String query;
  final ValueChanged<CartLine> onAdd;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('singles').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(
            child: Text(AppStrings.errorLoadingSingles),
          );
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text(AppStrings.emptySingles));
        }

        final Map<String, SingleGroup> groups = {};
        for (final doc in snap.data!.docs) {
          final data = doc.data();
          final name = (data['name'] ?? '').toString();
          final image = (data['image'] ?? 'assets/singles.jpg').toString();
          final variant = (data['variant'] ?? '').toString().trim();

          final sellPerKg = (data['sellPricePerKg'] is num)
              ? (data['sellPricePerKg'] as num).toDouble()
              : double.tryParse((data['sellPricePerKg'] ?? '0').toString()) ??
                    0.0;
          final costPerKg = (data['costPricePerKg'] is num)
              ? (data['costPricePerKg'] as num).toDouble()
              : double.tryParse((data['costPricePerKg'] ?? '0').toString()) ??
                    0.0;
          final unit = (data['unit'] ?? 'g').toString();

          groups.putIfAbsent(name, () => SingleGroup(name: name, image: image));
          groups[name]!.variants[variant] = SingleVariant(
            id: doc.id,
            name: name,
            variant: variant,
            image: image,
            sellPricePerKg: sellPerKg,
            costPricePerKg: costPerKg,
            unit: unit,
          );
        }

        final q = query.trim().toLowerCase();
        final items =
            groups.values
                .where((g) => q.isEmpty || g.name.toLowerCase().contains(q))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

        final cards = items
            .map(
              (it) => _CatalogItem(
                title: it.name,
                image: it.image,
                subtitle: AppStrings.labelVariantsCount(it.variants.length),
                onTap: () async {
                  try {
                    await showDialog(
                      context: context,
                      builder: (_) => SingleDialog(
                        group: it,
                        cartMode: true,
                        onAddToCart: onAdd,
                      ),
                    );
                  } catch (e, st) {
                    logError(e, st);
                    if (context.mounted) await showErrorDialog(context, e, st);
                  }
                },
              ),
            )
            .toList();

        return _CatalogGrid(items: cards);
      },
    );
  }
}

class _BlendsGrid extends StatelessWidget {
  const _BlendsGrid({required this.query, required this.onAdd});

  final String query;
  final ValueChanged<CartLine> onAdd;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('blends').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text(AppStrings.errorLoadingBlends));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text(AppStrings.emptyBlends));
        }

        final Map<String, BlendGroup> groups = {};
        for (final doc in snap.data!.docs) {
          final data = doc.data();
          final name = (data['name'] ?? '').toString();
          final image = (data['image'] ?? 'assets/blends.jpg').toString();
          final variant = (data['variant'] ?? '').toString().trim();

          final sellPerKg = (data['sellPricePerKg'] is num)
              ? (data['sellPricePerKg'] as num).toDouble()
              : double.tryParse((data['sellPricePerKg'] ?? '0').toString()) ??
                    0.0;
          final costPerKg = (data['costPricePerKg'] is num)
              ? (data['costPricePerKg'] as num).toDouble()
              : double.tryParse((data['costPricePerKg'] ?? '0').toString()) ??
                    0.0;

          final unit = (data['unit'] ?? 'g').toString();
          final stock = (data['stock'] is num)
              ? (data['stock'] as num).toDouble()
              : double.tryParse((data['stock'] ?? '0').toString()) ?? 0.0;

          groups.putIfAbsent(name, () => BlendGroup(name: name, image: image));

          groups[name]!.variants[variant] = BlendVariant(
            id: doc.id,
            name: name,
            variant: variant,
            image: image,
            sellPricePerKg: sellPerKg,
            costPricePerKg: costPerKg,
            unit: unit,
            stock: stock,
          );
        }

        final q = query.trim().toLowerCase();
        final items =
            groups.values
                .where((g) => q.isEmpty || g.name.toLowerCase().contains(q))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

        final cards = items
            .map(
              (it) => _CatalogItem(
                title: it.name,
                image: it.image,
                subtitle: AppStrings.labelVariantsCount(it.variants.length),
                onTap: () async {
                  try {
                    await showDialog(
                      context: context,
                      builder: (_) => BlendDialog(
                        group: it,
                        cartMode: true,
                        onAddToCart: onAdd,
                      ),
                    );
                  } catch (e, st) {
                    logError(e, st);
                    if (context.mounted) await showErrorDialog(context, e, st);
                  }
                },
              ),
            )
            .toList();

        return _CatalogGrid(items: cards);
      },
    );
  }
}

class _ExtrasGrid extends StatelessWidget {
  const _ExtrasGrid({required this.query, required this.onAdd});

  final String query;
  final ValueChanged<CartLine> onAdd;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('extras')
          .where('category', isEqualTo: 'biscuits')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text(AppStrings.errorLoadingExtras));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text(AppStrings.emptyExtras));
        }

        final q = query.trim().toLowerCase();
        final items =
            snap.data!.docs
                .map((doc) {
                  final data = doc.data();
                  final name = (data['name'] ?? '').toString();
                  final image = (data['image'] ?? 'assets/cookies.png')
                      .toString();
                  double numValue(v) => (v is num)
                      ? v.toDouble()
                      : double.tryParse('${v ?? ''}') ?? 0.0;
                  int intValue(v) =>
                      (v is num) ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

                  final priceSell = numValue(data['price_sell']);
                  final stock = intValue(data['stock_units']);

                  return (
                    id: doc.id,
                    name: name,
                    image: image,
                    price: priceSell,
                    stock: stock,
                    raw: data,
                  );
                })
                .where((it) {
                  if (q.isEmpty) return true;
                  return it.name.toLowerCase().contains(q);
                })
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

        final cards = items
            .map(
              (it) => _CatalogItem(
                title: it.name,
                image: it.image,
                subtitle: AppStrings.stockPiecesAr(it.stock),
                priceText: '${it.price.toStringAsFixed(2)} ج.م',
                onTap: () async {
                  try {
                    await showDialog(
                      context: context,
                      builder: (_) => ExtraDialog(
                        extraId: it.id,
                        extraData: it.raw,
                        cartMode: true,
                        onAddToCart: onAdd,
                      ),
                    );
                  } catch (e, st) {
                    logError(e, st);
                    if (context.mounted) await showErrorDialog(context, e, st);
                  }
                },
              ),
            )
            .toList();

        return _CatalogGrid(items: cards);
      },
    );
  }
}

class _CustomBlendEntry extends StatelessWidget {
  const _CustomBlendEntry({required this.onAdd});

  final ValueChanged<CartLine> onAdd;

  @override
  Widget build(BuildContext context) {
    final item = _CatalogItem(
      title: AppStrings.titleCustomBlendEntry,
      image: 'assets/custom.jpg',
      subtitle: AppStrings.subtitleCustomBlendEntry,
      onTap: () async {
        try {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  CustomBlendsPage(cartMode: true, onAddToCart: onAdd),
            ),
          );
        } catch (e, st) {
          logError(e, st);
          if (context.mounted) await showErrorDialog(context, e, st);
        }
      },
    );

    return _CatalogGrid(items: [item]);
  }
}
