import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:elfouad_coffee_beans/core/utils/app_breakpoints.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/di/di.dart';
import '../bloc/sales_history_cubit.dart';
import '../bloc/sales_history_state.dart';
import 'credit_accounts_page.dart';
import '../widgets/history_day_section.dart';
import '../utils/sale_utils.dart';

class SalesHistoryPage extends StatelessWidget {
  const SalesHistoryPage({super.key});

  static const route = '/sales-history';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SalesHistoryCubit>()..initialize(),
      child: const _SalesHistoryView(),
    );
  }
}

class _SalesHistoryView extends StatelessWidget {
  const _SalesHistoryView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<SalesHistoryCubit>();
    final state = cubit.state;
    final width = MediaQuery.of(context).size.width;
    final contentMaxWidth =
        AppBreakpoints.isWide(width) ? 1100.0 : double.infinity;
    final horizontalPadding = width < 600 ? 10.0 : 12.0;
    final listPadding = EdgeInsets.fromLTRB(
      horizontalPadding,
      12,
      horizontalPadding,
      24,
    );
    final showInitialLoading =
        state.isLoadingFirst && state.isEmpty && state.creditAccounts.isEmpty;
    final noHistoryLabel =
        state.isFiltered ? AppStrings.labelNoSalesInRange : AppStrings.labelNoSales;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _HistoryAppBar(cubit: cubit),
        floatingActionButton: _CreditFab(
          count: _creditUnpaidCount(state),
          isLoading: state.isCreditLoading,
          onTap: () {
            final cubit = context.read<SalesHistoryCubit>();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: const CreditAccountsPage(),
                ),
              ),
            );
          },
        ),
        body: showInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: contentMaxWidth,
                        ),
                        child: ListView(
                          padding: listPadding,
                          children: [
                            if (state.groups.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Center(child: Text(noHistoryLabel)),
                              )
                            else
                              ...state.groups.map((group) {
                                final overrideTotal =
                                    state.fullTotalsByDay[group.label];
                                final showLoading =
                                    state.isRangeTotalLoading &&
                                    overrideTotal == null;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: HistoryDaySection(
                                    group: group,
                                    overrideTotal: overrideTotal,
                                    showTotalLoading: showLoading,
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (state.isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (state.hasMore && !state.isLoadingFirst)
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentMaxWidth),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: cubit.loadMore,
                              child: const Text(AppStrings.btnLoadMore),
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

class _HistoryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HistoryAppBar({required this.cubit});

  final SalesHistoryCubit cubit;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final state = cubit.state;
    final titleSize =
        ResponsiveValue<double>(
          context,
          defaultValue: 28,
          conditionalValues: const [
            Condition.smallerThan(name: TABLET, value: 22),
            Condition.between(start: AppBreakpoints.tabletStart, end: AppBreakpoints.tabletEnd, value: 26),
            Condition.largerThan(name: DESKTOP, value: 32),
          ],
        ).value;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.maybePop(context),
          tooltip: AppStrings.tooltipBack,
        ),
        title: Text(
          AppStrings.titleSalesHistory,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: titleSize,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 8,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: AppStrings.tooltipFilterByDate,
            onPressed: () => _pickRange(context, cubit),
            icon: const Icon(Icons.filter_alt, color: Colors.white),
          ),
          if (state.isFiltered)
            IconButton(
              tooltip: AppStrings.tooltipClearFilter,
              onPressed: () async => cubit.setRange(null),
              icon: const Icon(Icons.clear),
            ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5D4037), Color(0xFF795548)],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickRange(
    BuildContext context,
    SalesHistoryCubit cubit,
  ) async {
    final now = DateTime.now();
    final init = cubit.state.customRange ?? defaultSalesRange();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: init,
      locale: const Locale('ar'),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );

    if (picked != null) {
      final normalized = cubit.normalizePickerRange(picked);
      await cubit.setRange(normalized);
    }
  }
}

int _creditUnpaidCount(SalesHistoryState state) {
  int total = 0;
  for (final account in state.creditAccounts) {
    total += account.unpaidCount;
  }
  return total;
}

class _CreditFab extends StatelessWidget {
  const _CreditFab({
    required this.count,
    required this.isLoading,
    required this.onTap,
  });

  final int count;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton.extended(
          onPressed: onTap,
          icon: const Icon(Icons.account_balance_wallet_rounded),
          label: const Text(AppStrings.titleCreditAccounts),
        ),
        if (count > 0 || isLoading)
          Positioned(
            top: -4,
            right: -4,
            child: _CreditBadge(count: count, isLoading: isLoading),
          ),
      ],
    );
  }
}

class _CreditBadge extends StatelessWidget {
  const _CreditBadge({required this.count, required this.isLoading});

  final int count;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final background = count > 0 ? Colors.orange.shade700 : Colors.grey.shade400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
          ),
        ],
      ),
      child: isLoading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}


