// lib/drinks.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/drink_dialog.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_breakpoints.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

class DrinksPage extends StatelessWidget {
  const DrinksPage({super.key});

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
      // ===== AppBar رايق بجراديانت وحدود سفلية ناعمة =====
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
              AppStrings.titleDrinksSection,
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
        stream: FirebaseFirestore.instance.collection('drinks').snapshots(),
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
            return const Center(child: Text(AppStrings.errorLoadingDrinks));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text(AppStrings.noDrinks));
          }

          late final List<_DrinkItem> items;
          try {
            items = snap.data!.docs.map((doc) {
              final data = doc.data();
              final name = (data['name'] ?? '').toString();
              final image = (data['image'] ?? 'assets/drinks.jpg').toString();
              final unit = (data['unit'] ?? 'cup').toString();
              final sellPrice = (data['sellPrice'] is num)
                  ? (data['sellPrice'] as num).toDouble()
                  : double.tryParse((data['sellPrice'] ?? '0').toString()) ??
                        0.0;

              return _DrinkItem(
                id: doc.id,
                name: name,
                image: image,
                data: {...data, 'unit': unit, 'sellPrice': sellPrice},
              );
            }).toList();

            // === Custom sort: preferred order first, then alphabetical ===
            const preferredOrderDrinks = <String>[
              'قهوة تركي',
              'قهوة اسبريسو',
              'قهوة فرنساوي',
              'قهوة بندق قطع',
              'قهوة كراميل',
              'شاي',
              'كوفي ميكس',
            ];
            final rankDrinks = <String, int>{
              for (var i = 0; i < preferredOrderDrinks.length; i++)
                preferredOrderDrinks[i]: i,
            };
            items.sort((a, b) {
              final ra = rankDrinks[a.name] ?? 1 << 20;
              final rb = rankDrinks[b.name] ?? 1 << 20;
              if (ra != rb) return ra.compareTo(rb);
              return a.name.compareTo(b.name);
            });
            // === End custom sort ===
          } catch (e, st) {
            logError(e, st);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) showErrorDialog(context, e, st);
            });
            return const Center(child: Text(AppStrings.errorReadingDrinks));
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
                  return _DrinkCard(
                    title: it.name,
                    image: it.image,
                    onTap: () async {
                      try {
                        await showDialog(
                          context: context,
                          builder: (_) =>
                              DrinkDialog(drinkId: it.id, drinkData: it.data),
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

class _DrinkItem {
  final String id;
  final String name;
  final String image;
  final Map<String, dynamic> data;
  _DrinkItem({
    required this.id,
    required this.name,
    required this.image,
    required this.data,
  });
}

class _DrinkCard extends StatelessWidget {
  final String title;
  final String image;
  final VoidCallback onTap;
  const _DrinkCard({
    required this.title,
    required this.image,
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
            Image.asset(image, fit: BoxFit.cover),
            // طبقة تغميق خفيفة
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            // الاسم في "نص" الكارت بخلفية شفافة خفيفة
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}


