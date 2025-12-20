import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/view/custom_blends_page.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/blends_models.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/cart_state.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/singles_models.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/blend_dialog.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/drink_dialog.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/extra_dialog.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/single_dialog.dart';
import 'package:elfouad_coffee_beans/Presentation/features/sales/utils/sale_utils.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';

import 'catalog_widgets.dart';

class DrinksGrid extends StatelessWidget {
  const DrinksGrid({super.key, required this.query, required this.onAdd});

  final String query;
  final ValueChanged<CartLine> onAdd;
  static final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance.collection('drinks').snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
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
                  final image = (data['image'] ?? 'assets/drinks.jpg').toString();
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
              (it) => CatalogItem(
                title: it.name,
                image: it.image,
                priceText:
                    '${it.price.toStringAsFixed(2)} ${AppStrings.currencyEgpLetter}',
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

        return CatalogGrid(items: cards);
      },
    );
  }
}

class SinglesGrid extends StatelessWidget {
  const SinglesGrid({super.key, required this.query, required this.onAdd});

  final String query;
  final ValueChanged<CartLine> onAdd;
  static final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance.collection('singles').snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text(AppStrings.errorLoadingSingles));
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
              (it) => CatalogItem(
                title: it.name,
                image: it.image,
                subtitle: AppStrings.variantsCount(it.variants.length),
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

        return CatalogGrid(items: cards);
      },
    );
  }
}

class BlendsGrid extends StatelessWidget {
  const BlendsGrid({super.key, required this.query, required this.onAdd});

  final String query;
  final ValueChanged<CartLine> onAdd;
  static final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance.collection('blends').snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
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
              (it) => CatalogItem(
                title: it.name,
                image: it.image,
                subtitle: AppStrings.variantsCount(it.variants.length),
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

        return CatalogGrid(items: cards);
      },
    );
  }
}

class ExtrasGrid extends StatelessWidget {
  const ExtrasGrid({super.key, required this.query, required this.onAdd});

  final String query;
  final ValueChanged<CartLine> onAdd;
  static final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance
          .collection('extras')
          .where('category', isEqualTo: 'biscuits')
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
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
              (it) => CatalogItem(
                title: it.name,
                image: it.image,
                subtitle: AppStrings.stockPiecesAr(it.stock),
                priceText:
                    '${it.price.toStringAsFixed(2)} ${AppStrings.currencyEgpLetter}',
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

        return CatalogGrid(items: cards);
      },
    );
  }
}

class CustomBlendEntry extends StatelessWidget {
  const CustomBlendEntry({super.key, required this.onAdd});

  final ValueChanged<CartLine> onAdd;
  static final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance
          .collection('custom_blends')
          .orderBy('created_at', descending: true)
          .limit(30)
          .snapshots();

  String? _formatCreatedAt(dynamic value) {
    final createdAt = parseOptionalDate(value);
    if (createdAt == null) return null;
    return formatDateTime(createdAt);
  }

  Future<void> _deleteBlend(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawTitle = (data['title'] ?? '').toString().trim();
    final title =
        rawTitle.isEmpty ? AppStrings.labelCustomBlendSingle : rawTitle;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.dialogConfirm),
        content: Text(AppStrings.confirmDeleteCustomBlend(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.dialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8B3A2A),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text(AppStrings.dialogConfirm),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await doc.reference.delete();
    } catch (e, st) {
      logError(e, st);
      if (context.mounted) await showErrorDialog(context, e, st);
    }
  }

  Future<void> _openBlend(
    BuildContext context, {
    Map<String, dynamic>? initialBlend,
  }) async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomBlendsPage(
            cartMode: true,
            onAddToCart: onAdd,
            initialBlend: initialBlend,
          ),
        ),
      );
    } catch (e, st) {
      logError(e, st);
      if (context.mounted) await showErrorDialog(context, e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prepareItem = CatalogItem(
      title: AppStrings.titlePrepareCustomBlend,
      image: 'assets/custom.jpg',
      subtitle: AppStrings.descMixCoffeeAsYouLike,
      onTap: () => _openBlend(context),
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final items = <CatalogItem>[prepareItem];
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final data = doc.data();
            final rawTitle = (data['title'] ?? '').toString().trim();
            final title = rawTitle.isEmpty
                ? AppStrings.labelCustomBlendSingle
                : rawTitle;
            final createdLabel = _formatCreatedAt(data['created_at']);
            items.add(
              CatalogItem(
                title: title,
                image: 'assets/custom.jpg',
                subtitle: createdLabel,
                onTap: () => _openBlend(context, initialBlend: data),
                onDelete: () => _deleteBlend(context, doc),
              ),
            );
          }
        }

        return CatalogGrid(items: items);
      },
    );
  }
}
