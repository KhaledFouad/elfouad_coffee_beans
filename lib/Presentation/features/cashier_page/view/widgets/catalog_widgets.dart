import 'package:flutter/material.dart';

import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';

class CatalogItem {
  CatalogItem({
    required this.title,
    required this.image,
    required this.onTap,
    this.subtitle,
    this.priceText,
    this.onDelete,
  });

  final String title;
  final String image;
  final String? subtitle;
  final String? priceText;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
}

class CatalogGrid extends StatelessWidget {
  const CatalogGrid({super.key, required this.items});

  final List<CatalogItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text(AppStrings.noMatchingItems));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final max = constraints.maxWidth;
        final cross = max >= 1200
            ? 4
            : max >= 900
                ? 3
                : max >= 600
                    ? 2
                    : 1;
        final aspect = max >= 1200
            ? 2.6
            : max >= 900
                ? 2.5
                : max >= 600
                    ? 2.4
                    : 2.2;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: aspect,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => CatalogCard(item: items[i]),
        );
      },
    );
  }
}

class CatalogCard extends StatelessWidget {
  const CatalogCard({super.key, required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: Colors.brown.shade50,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: Color(0xFF3F2A1D),
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (item.priceText != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.priceText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF543824),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (item.onDelete != null)
              PositionedDirectional(
                top: 8,
                start: 8,
                child: Material(
                  color: Colors.white70,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: item.onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Color(0xFF8B3A2A),
                      ),
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
