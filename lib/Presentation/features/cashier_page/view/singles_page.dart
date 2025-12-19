import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/singles_models.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/single_dialog.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_breakpoints.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

class SinglesPage extends StatelessWidget {
  const SinglesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final titleSize =
        ResponsiveValue<double>(
          context,
          defaultValue: 22,
          conditionalValues: const [
            Condition.smallerThan(name: TABLET, value: 20),
            Condition.largerThan(name: DESKTOP, value: 26),
          ],
        ).value;

    return Scaffold(
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
              AppStrings.titleSinglesSection,
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
        stream: FirebaseFirestore.instance.collection('singles').snapshots(),
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
            return const Center(child: Text(AppStrings.errorLoadingSingles));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text(AppStrings.emptySinglesShort));
          }

          // === تجميع حسب الاسم (بدون تكرار) ===
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

            groups.putIfAbsent(
              name,
              () => SingleGroup(name: name, image: image),
            );

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

          final items = groups.values.toList();

          return LayoutBuilder(
            builder: (context, c) {
              final max = c.maxWidth;
              final cross = AppBreakpoints.gridCount(max);

              return GridView.builder(
                padding: AppBreakpoints.gridPagePadding(max),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.25,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final it = items[i];
                  return _SingleCard(
                    title: it.name,
                    image: it.image,
                    onTap: () async {
                      try {
                        await showDialog(
                          context: context,
                          builder: (_) => SingleDialog(group: it),
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

class _SingleCard extends StatelessWidget {
  final String title;
  final String image;
  final VoidCallback onTap;
  const _SingleCard({
    required this.title,
    required this.image,
    required this.onTap,
  });

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
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
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


