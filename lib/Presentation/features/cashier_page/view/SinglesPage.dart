import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/singles_models.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/singleDialog.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:flutter/material.dart';

class SinglesPage extends StatelessWidget {
  const SinglesPage({super.key});

  @override
  Widget build(BuildContext context) {
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
              tooltip: 'رجوع',
            ),
            title: const Text(
              'أصناف منفردة',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
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
            return const Center(child: Text('حدث خطأ أثناء تحميل الأصناف'));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('لا يوجد أصناف منفردة'));
          }

          // === تجميع حسب الاسم (بدون تكرار) ===
          final Map<String, SingleGroup> groups = {};
          for (final doc in snap.data!.docs) {
            final data = doc.data();
            final name = (data['name'] ?? '').toString();
            final image = (data['image'] ?? 'assets/singles.jpg').toString();
            final variant = (data['variant'] ?? '')
                .toString()
                .trim(); // فاتح/وسط/غامق أو ""

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
              final cross = max >= 1200
                  ? 4
                  : max >= 900
                  ? 3
                  : max >= 600
                  ? 2
                  : 1;

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
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
                        if (context.mounted)
                          await showErrorDialog(context, e, st);
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
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.55),
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
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 35,
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
