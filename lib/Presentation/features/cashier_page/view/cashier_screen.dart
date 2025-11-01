import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/view/extras_page.dart'
    show ExtrasPage;
import 'package:elfouad_coffee_beans/Presentation/features/sales/sales_history_page.dart';
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
        "title": "معمول و تمر",
        "icon": FontAwesomeIcons.cookie,
        "image": "assets/cookies.png",
        "builder": (BuildContext _) => const ExtrasPage(),
      },
      {
        "title": "توليفات العميل",
        "icon": FontAwesomeIcons.userGear,
        "image": "assets/custom.jpg",
        "builder": (BuildContext _) => const CustomBlendsPage(),
      },
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // ==== FAB مع بادچ لعدد عمليات الأجل غير المسددة ====
        floatingActionButton: _SalesHistoryFabWithBadge(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

        backgroundColor: const Color(0xFFF5F5F5),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth.clamp(0, 1100.0);
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

/// ==== FAB يُظهِر بادچ بعدد العمليات المؤجلة غير المسددة ====
class _SalesHistoryFabWithBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('sales')
        .where('is_deferred', isEqualTo: true)
        .where('paid', isEqualTo: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            FloatingActionButton.extended(
              backgroundColor: const Color(0xFF543824),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SalesHistoryPage()),
                );
              },
              icon: const Icon(Icons.receipt_long, color: Colors.white),
              label: const Text(
                'سجلّ المبيعات',
                style: TextStyle(color: Colors.white),
              ),
            ),
            if (count > 0)
              Positioned(
                // تحريك بسيط لأعلى/يمين عشان يبان فوق الـ FAB
                right: -4,
                top: -4,
                child: _Badge(count: count),
              ),
          ],
        );
      },
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
      constraints: const BoxConstraints(minWidth: 22, minHeight: 18),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      child: Center(
        child: Text(
          text,
          textScaleFactor: 1.0,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ),
    );
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
    if (!kIsWeb) return;
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
                  Image.asset(
                    widget.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey.shade300),
                  ),
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
