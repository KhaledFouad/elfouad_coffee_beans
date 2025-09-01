// lib/drinks.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/DrinkDialog.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:flutter/material.dart';
// logError(..), showErrorDialog(..)

class DrinksPage extends StatelessWidget {
  const DrinksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('drinks').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            // خطأ على مستوى الستريم
            final e = snap.error!;
            logError(e, snap.stackTrace);
            // ديالوج بنص قابل للنسخ
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
              // تأكد إن الحقول الأساسية موجودة وأنواعها سليمة
              final name = (data['name'] ?? '').toString();
              final image = (data['image'] ?? 'assets/drinks.jpg').toString();

              // دي حقول اختيارية لكن هنحافظ على الأنواع
              final unit = (data['unit'] ?? 'cup').toString();
              final sellPrice = (data['sellPrice'] ?? 0).toDouble();

              // مهم: لو عندك roastLevels أو consumesByRoast / consumes، سيبهم زي ما هم (الديالوج بيتعامل)
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

          // نفس شكل الكروت: صورة خلفية داكنة + اسم كبير
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
              final spacing = 16.0;

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
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
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
                    Colors.black.withOpacity(0.20),
                    Colors.black.withOpacity(0.60),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
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
