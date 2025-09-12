// import 'package:flutter/material.dart';

// class ItemCard extends StatelessWidget {
//   final String title;
//   final List<Map<String, dynamic>> items;

//   const ItemCard({super.key, required this.title, required this.items});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 22))),
//       body: LayoutBuilder(
//         builder: (context, constraints) {
//           final boxSize = (constraints.maxWidth / 2).clamp(220.0, 320.0);

//           return Center(
//             child: SingleChildScrollView(
//               child: ConstrainedBox(
//                 constraints: const BoxConstraints(maxWidth: 900),
//                 child: Wrap(
//                   spacing: 20,
//                   runSpacing: 20,
//                   alignment: WrapAlignment.center,
//                   children: items.map((item) {
//                     return _ItemCard(
//                       title: item["name"]?.toString() ?? "",
//                       image:
//                           item["image"]?.toString() ?? "assets/placeholder.jpg",
//                       size: boxSize,
//                       onTap: () {
//                         debugPrint("✅ ${item["name"]} pressed");
//                       },
//                     );
//                   }).toList(),
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// class _ItemCard extends StatefulWidget {
//   final String title;
//   final String image;
//   final double size;
//   final VoidCallback onTap;

//   const _ItemCard({
//     required this.title,
//     required this.image,
//     required this.size,
//     required this.onTap,
//   });

//   @override
//   State<_ItemCard> createState() => _ItemCardState();
// }

// class _ItemCardState extends State<_ItemCard>
//     with SingleTickerProviderStateMixin {
//   double _scale = 1.0;

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedScale(
//       scale: _scale,
//       duration: const Duration(milliseconds: 200),
//       child: Material(
//         elevation: 6,
//         borderRadius: BorderRadius.circular(20),
//         clipBehavior: Clip.antiAlias,
//         child: InkWell(
//           onTap: widget.onTap,
//           onHover: (hovering) {
//             setState(() {
//               _scale = hovering ? 1.05 : 1.0;
//             });
//           },
//           splashColor: Colors.white.withOpacity(0.3),
//           highlightColor: Colors.transparent,
//           child: Container(
//             width: widget.size * 1.3,
//             height: widget.size * 0.88,
//             decoration: BoxDecoration(
//               image: DecorationImage(
//                 image: AssetImage(widget.image),
//                 fit: BoxFit.cover,
//                 colorFilter: ColorFilter.mode(
//                   Colors.black.withOpacity(0.55),
//                   BlendMode.darken,
//                 ),
//               ),
//             ),
//             child: Center(
//               child: Text(
//                 widget.title,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 28,
//                   fontWeight: FontWeight.bold,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
