// lib/drinks.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/DrinkDialog.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:flutter/material.dart';

class DrinksPage extends StatelessWidget {
  const DrinksPage({super.key});

  @override
  Widget build(BuildContext context) {
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
              tooltip: 'رجوع',
            ),
            title: const Text(
              'المشروبات',
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
            return const Center(child: Text('حدث خطأ أثناء تحميل المشروبات'));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('لا يوجد مشروبات'));
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
          } catch (e, st) {
            logError(e, st);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) showErrorDialog(context, e, st);
            });
            return const Center(child: Text('تعذر قراءة بيانات المشروبات'));
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
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.55),
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
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
