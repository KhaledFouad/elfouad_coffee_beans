import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/cart_state.dart';
import 'package:elfouad_coffee_beans/Presentation/features/sales/pages/sales_history_page.dart';
import 'package:elfouad_coffee_beans/core/di/di.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_breakpoints.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/bloc/cart_cubit.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/bloc/cashier_cubit.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/bloc/cashier_state.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/view/widgets/cashier_header.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/view/widgets/cashier_sidebar.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/view/widgets/cart_panel.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/view/widgets/catalog_sections.dart';

class CashierHome extends StatelessWidget {
  const CashierHome({super.key});
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<CartCubit>(create: (_) => getIt<CartCubit>()),
          BlocProvider<CashierCubit>(create: (_) => getIt<CashierCubit>()),
        ],
        child: const _PosShell(),
      ),
    );
  }
}

class _PosShell extends StatefulWidget {
  const _PosShell();

  @override
  State<_PosShell> createState() => _PosShellState();
}

class _PosShellState extends State<_PosShell> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl.addListener(() {
      context.read<CartCubit>().setInvoiceNote(_noteCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartCubit>().cart;
    final cashierState = context.watch<CashierCubit>().state;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = AppBreakpoints.isCompact(width);
        final isWide = AppBreakpoints.isDesktop(width);
        final cartPanelWidth = isWide ? 360.0 : 320.0;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F3EF),
          drawer: isCompact
              ? Drawer(
                  child: SafeArea(
                    child: CashierSidebar(
                      compact: true,
                      selectedCategory: cashierState.selectedCategory,
                      onSelect: (category) =>
                          context.read<CashierCubit>().selectCategory(category),
                      onOpenSalesHistory: _openSalesHistory,
                    ),
                  ),
                )
              : null,
          endDrawer: isCompact
              ? Drawer(
                  child: SafeArea(
                    child: CartPanel(
                      noteCtrl: _noteCtrl,
                      checkingOut: _checkingOut,
                      onCheckout: () => _checkout(cart),
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            child: Builder(
              builder: (context) {
                final catalogPadding = EdgeInsets.fromLTRB(
                  12,
                  isCompact ? 6 : 8,
                  12,
                  12,
                );

                if (isCompact) {
                  return Column(
                    children: [
                      CashierHeader(
                        compact: true,
                        searchController: _searchCtrl,
                        onOpenMenu: () => Scaffold.of(context).openDrawer(),
                        onOpenCart: () => Scaffold.of(context).openEndDrawer(),
                        onRefresh: () => setState(() {}),
                      ),
                      Expanded(
                        child: Padding(
                          padding: catalogPadding,
                          child: _buildCatalog(
                            cart,
                            cashierState.selectedCategory,
                            cashierState.searchQuery,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CashierSidebar(
                      selectedCategory: cashierState.selectedCategory,
                      onSelect: (category) =>
                          context.read<CashierCubit>().selectCategory(category),
                      onOpenSalesHistory: _openSalesHistory,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          CashierHeader(
                            compact: false,
                            searchController: _searchCtrl,
                            onRefresh: () => setState(() {}),
                          ),
                          Expanded(
                            child: Padding(
                              padding: catalogPadding,
                              child: _buildCatalog(
                                cart,
                                cashierState.selectedCategory,
                                cashierState.searchQuery,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: cartPanelWidth,
                      child: CartPanel(
                        noteCtrl: _noteCtrl,
                        checkingOut: _checkingOut,
                        onCheckout: () => _checkout(cart),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCatalog(
    CartState cart,
    CashierCategory selectedCategory,
    String query,
  ) {
    switch (selectedCategory) {
      case CashierCategory.drinks:
        return DrinksGrid(query: query, onAdd: _addLine);
      case CashierCategory.singles:
        return SinglesGrid(query: query, onAdd: _addLine);
      case CashierCategory.blends:
        return BlendsGrid(query: query, onAdd: _addLine);
      case CashierCategory.extras:
        return ExtrasGrid(query: query, onAdd: _addLine);
      case CashierCategory.custom:
        return CustomBlendEntry(onAdd: _addLine);
    }
  }

  void _openSalesHistory() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SalesHistoryPage()));
  }

  void _addLine(CartLine line) {
    context.read<CartCubit>().addLine(line);
  }

  Future<void> _checkout(CartState cart) async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.cartEmptyAddProductsFirst)),
      );
      return;
    }
    final cartCubit = context.read<CartCubit>();
    setState(() => _checkingOut = true);
    try {
      await CartCheckout.commitInvoice(cart: cart);
      cartCubit.clear();
      _noteCtrl.clear();
    } catch (e, st) {
      logError(e, st);
      if (!mounted) return;
      await showErrorDialog(context, e, st);
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }
}
