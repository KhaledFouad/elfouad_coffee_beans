import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/singleDialog.dart';
import 'package:flutter/material.dart';

class SinglesPage extends StatelessWidget {
  const SinglesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الأصناف المنفردة", style: TextStyle(fontSize: 22)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("products").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("❌ لا يوجد أصناف حالياً"));
          }

          // 🛠️ إزالة التكرار (نجيب أسماء مميزة فقط)
          final docs = snapshot.data!.docs;
          final Map<String, QueryDocumentSnapshot> uniqueItems = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            uniqueItems[data['name']] = doc;
          }

          final items = uniqueItems.values.toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final boxSize = (constraints.maxWidth / 2).clamp(220.0, 320.0);

              return Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: items.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _SingleCard(
                          title: data['name'] ?? "",
                          image: data['image'] ?? "assets/singles.jpg",
                          size: boxSize,
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => SingleDialog(
                                title: data['name'],
                                image: data['image'] ?? "assets/singles.jpg",
                                doc: doc,
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SingleCard extends StatefulWidget {
  final String title;
  final String image;
  final double size;
  final VoidCallback onTap;

  const _SingleCard({
    required this.title,
    required this.image,
    required this.size,
    required this.onTap,
  });

  @override
  State<_SingleCard> createState() => _SingleCardState();
}

class _SingleCardState extends State<_SingleCard>
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
            child: Center(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
