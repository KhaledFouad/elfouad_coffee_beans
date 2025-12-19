import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/bloc/cart_cubit.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/bloc/cashier_cubit.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';

import 'badge.dart';

class CashierHeader extends StatelessWidget {
  const CashierHeader({
    super.key,
    required this.compact,
    required this.searchController,
    this.onOpenMenu,
    this.onOpenCart,
    this.onRefresh,
  });

  final bool compact;
  final TextEditingController searchController;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onOpenCart;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 20.0 : 24.0;
    final padding = compact
        ? const EdgeInsets.fromLTRB(12, 10, 12, 6)
        : const EdgeInsets.fromLTRB(16, 12, 16, 6);

    final searchField = TextField(
      controller: searchController,
      onChanged: (value) =>
          context.read<CashierCubit>().updateSearch(value),
      decoration: InputDecoration(
        hintText: AppStrings.hintSearchProduct,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );

    final cartButton = BlocBuilder<CartCubit, CartViewState>(
      builder: (context, state) {
        final count = state.cart.lines.length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: AppStrings.titleCart,
              onPressed: onOpenCart,
              icon: const Icon(Icons.shopping_cart_outlined),
            ),
            if (count > 0)
              Positioned(
                top: -2,
                right: -2,
                child: CountBadge(count: count),
              ),
          ],
        );
      },
    );

    if (compact) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: AppStrings.titleSections,
                  onPressed: onOpenMenu,
                  icon: const Icon(Icons.menu),
                ),
                Text(
                  AppStrings.titlePos,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (kIsWeb)
                  IconButton(
                    tooltip: AppStrings.tooltipRefresh,
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
                cartButton,
              ],
            ),
            const SizedBox(height: 8),
            searchField,
          ],
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            AppStrings.titlePos,
            style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 16),
          Expanded(child: searchField),
          const SizedBox(width: 12),
          if (kIsWeb)
            IconButton(
              tooltip: AppStrings.tooltipRefresh,
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    );
  }
}
