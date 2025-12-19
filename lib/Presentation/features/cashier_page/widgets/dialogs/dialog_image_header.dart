import 'package:flutter/material.dart';

class DialogImageHeader extends StatelessWidget {
  const DialogImageHeader({
    super.key,
    required this.image,
    required this.title,
    this.height = 140,
    this.radius = 18,
  });

  final String image;
  final String title;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      child: Stack(
        children: [
          Image.asset(
            image,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
