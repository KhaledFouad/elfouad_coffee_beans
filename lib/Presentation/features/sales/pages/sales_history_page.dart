import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:elfouad_coffee_beans/core/utils/app_breakpoints.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/di/di.dart';
import '../bloc/sales_history_cubit.dart';
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _HistoryAppBar(cubit: cubit),
        body: state.isEmpty && state.isLoadingFirst
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: state.isEmpty
                        ? const Center(child: Text(AppStrings.labelNoSales))
                        : Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: contentMaxWidth,
                              ),
                              child: ListView.builder(
                                padding: listPadding,
                                itemCount: state.groups.length,
                                itemBuilder: (context, index) {
                                  final group = state.groups[index];

                                  // ??? ????? ???????? ??????? ????? ?? ?? ?????
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
                                },
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


