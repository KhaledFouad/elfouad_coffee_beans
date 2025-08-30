import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CashierHome extends StatelessWidget {
  const CashierHome({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {
        "title": "مشروبات",
        "icon": FontAwesomeIcons.mugHot,
        "image": "assets/drinks.jpg",
      },
      {
        "title": "أصناف منفردة",
        "icon": FontAwesomeIcons.cookieBite,
        "image": "assets/singles.jpg",
      },
      {
        "title": "توليفات جاهزة",
        "icon": FontAwesomeIcons.cubes,
        "image": "assets/blends.jpg",
      },
      {
        "title": "توليفات العميل",
        "icon": FontAwesomeIcons.userGear,
        "image": "assets/custom.jpg",
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: LayoutBuilder(
        builder: (context, constraints) {
          // حجم المربع بيتحدد من الشاشة
          final boxSize = (constraints.maxWidth / 2).clamp(220.0, 320.0);

          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ), // البادنج العام
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 900, // أقصى عرض للمنطقة كلها
                  ),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: categories.map((cat) {
                      return _CategoryCard(
                        title: cat["title"] as String,
                        icon: cat["icon"] as IconData,
                        image: cat["image"] as String,
                        size: boxSize,
                        onTap: () {
                          debugPrint("✅ ${cat["title"]} pressed");
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final String image;
  final double size;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.image,
    required this.size,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 200),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (hovering) {
            setState(() {
              _scale = hovering ? 1.05 : 1.0;
            });
          },
          splashColor: Colors.white.withOpacity(0.3),
          highlightColor: Colors.transparent,
          child: Container(
            width: widget.size * 1.3,
            height: widget.size * 0.88,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(widget.image),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.55),
                  BlendMode.darken,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 40),
                const SizedBox(height: 10),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
