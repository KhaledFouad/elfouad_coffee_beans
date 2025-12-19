import 'package:flutter/material.dart';

import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/bloc/cashier_state.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';

class CashierSidebar extends StatelessWidget {
  const CashierSidebar({
    super.key,
    required this.selectedCategory,
    required this.onSelect,
    required this.onOpenSalesHistory,
    this.compact = false,
  });

  final CashierCategory selectedCategory;
  final ValueChanged<CashierCategory> onSelect;
  final VoidCallback onOpenSalesHistory;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const items = [
      (CashierCategory.drinks, AppStrings.titleDrinksSection, Icons.local_cafe),
      (
        CashierCategory.singles,
        AppStrings.titleSinglesSection,
        Icons.coffee_outlined,
      ),
      (
        CashierCategory.blends,
        AppStrings.titleBlendsSection,
        Icons.blender_outlined,
      ),
      (CashierCategory.extras, AppStrings.titleCookiesSection, Icons.cookie),
      (
        CashierCategory.custom,
        AppStrings.titleCustomBlendSection,
        Icons.auto_awesome_motion,
      ),
    ];

    final width = MediaQuery.of(context).size.width;
    final isTabletWidth = width >= 800;

    final sidebarWidth = isTabletWidth ? 240.0 : 200.0;
    final buttonHeight = isTabletWidth ? 72.0 : 60.0;
    final fontSize = isTabletWidth ? 18.0 : 16.0;
    final iconSize = isTabletWidth ? 24.0 : 22.0;
    final titleSize = compact ? 20.0 : 22.0;
    final topPadding = compact ? 16.0 : 20.0;

    return Container(
      width: compact ? null : sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(12, topPadding, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.titleSections,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          ...items.map((item) {
            final selected = selectedCategory == item.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: buttonHeight,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF543824)
                          : Colors.brown.shade100,
                      width: selected ? 1.6 : 1,
                    ),
                    backgroundColor:
                        selected ? const Color(0xFFF3EDE7) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: selected ? null : () => onSelect(item.$1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? const Color(0xFF543824)
                              : const Color(0xFF7D6B5B),
                        ),
                      ),
                      Icon(item.$3, size: iconSize),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          const Divider(),
          ListTile(
            dense: false,
            minVerticalPadding: 14,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.receipt_long, size: 26),
            title: const Text(
              AppStrings.titleSalesHistorySimple,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            onTap: onOpenSalesHistory,
          ),
        ],
      ),
    );
  }
}
