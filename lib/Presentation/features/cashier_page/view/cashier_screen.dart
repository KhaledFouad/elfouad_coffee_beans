import 'package:elfouad_coffee_beans/Presentation/features/admin/sales_history_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'SinglesPage.dart';
import 'blends_page.dart';
import 'custom_blends_page.dart';
import 'drinks.dart';

class CashierHome extends StatelessWidget {
  const CashierHome({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {
        "title": "مشروبات",
        "icon": FontAwesomeIcons.mugHot,
        "image": "assets/drinks.jpg",
        "builder": (BuildContext _) => const DrinksPage(),
      },
      {
        "title": "أصناف منفردة",
        "icon": FontAwesomeIcons.cookieBite,
        "image": "assets/singles.jpg",
        "builder": (BuildContext _) => const SinglesPage(),
      },
      {
        "title": "توليفات جاهزة",
        "icon": FontAwesomeIcons.cubes,
        "image": "assets/blends.jpg",
        "builder": (BuildContext _) => const BlendsPage(),
      },
      {
        "title": "توليفات العميل",
        "icon": FontAwesomeIcons.userGear,
        "image": "assets/custom.jpg",
        "builder": (BuildContext _) => const CustomBlendsPage(),
      },
    ];

    return Directionality(
      // يضمن RTL
      textDirection: TextDirection.rtl,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SalesHistoryPage()));
          },
          icon: const Icon(Icons.receipt_long),
          label: const Text('سجلّ المبيعات'),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        backgroundColor: const Color(0xFFF5F5F5),
        body: LayoutBuilder(
          builder: (context, constraints) {
            // عرض المحتوى الأقصى لراحة القراءة على الويب
            final maxW = constraints.maxWidth.clamp(0, 1100.0);
            // حجم الكارت حسب الشاشة
            final cardW = (maxW / 2).clamp(220.0, 340.0);
            final cardH = cardW * 0.85;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: categories.map((cat) {
                      return _CategoryCard(
                        title: cat["title"] as String,
                        icon: cat["icon"] as IconData,
                        image: cat["image"] as String,
                        width: cardW,
                        height: cardH,
                        onTap: () => _push(
                          context,
                          cat["builder"] as Widget Function(BuildContext),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget Function(BuildContext) builder) {
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }
}

class _CategoryCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final String image;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.image,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _setHover(bool hover) {
    if (!kIsWeb) return; // hover للويب فقط
    setState(() => _scale = hover ? 1.04 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            splashColor: Colors.white.withOpacity(0.25),
            highlightColor: Colors.transparent,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // الخلفية
                  Image.asset(
                    widget.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey.shade300),
                  ),
                  // تظليل/جراديانت
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.15),
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                  // المحتوى
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, color: Colors.white, size: 42),
                        const SizedBox(height: 10),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
