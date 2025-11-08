import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/sales_history_repository.dart';
import '../viewmodels/sales_history_view_model.dart';
import '../widgets/history_day_section.dart';
import '../utils/sale_utils.dart';

class SalesHistoryPage extends StatelessWidget {
  const SalesHistoryPage({super.key});

  static const route = '/sales-history';

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SalesHistoryViewModel(
        repository: SalesHistoryRepository(FirebaseFirestore.instance),
      ),
      child: const _SalesHistoryView(),
    );
  }
}

class _SalesHistoryView extends StatelessWidget {
  const _SalesHistoryView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SalesHistoryViewModel>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _HistoryAppBar(viewModel: viewModel),
        body: StreamBuilder<SalesHistoryState>(
          stream: viewModel.historyStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('خطأ في تحميل السجل: ${snapshot.error}'),
              );
            }

            final state = snapshot.data;
            if (state == null || state.isEmpty) {
              return const Center(child: Text('لا يوجد عمليات بيع')); 
            }

            final groups = state.groups;
            if (groups.isEmpty) {
              return const Center(child: Text('لا يوجد عمليات في هذا النطاق'));
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HistoryDaySection(group: groups[index]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HistoryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HistoryAppBar({required this.viewModel});

  final SalesHistoryViewModel viewModel;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
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
          tooltip: 'رجوع',
        ),
        title: const Text(
          'سجلّ المبيعات',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 35,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 8,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'تصفية بالتاريخ',
            onPressed: () => _pickRange(context, viewModel),
            icon: const Icon(Icons.filter_alt, color: Colors.white),
          ),
          if (viewModel.isFiltered)
            IconButton(
              tooltip: 'مسح الفلتر',
              onPressed: () => viewModel.setRange(null),
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
    SalesHistoryViewModel viewModel,
  ) async {
    final now = DateTime.now();
    final init = viewModel.customRange ?? defaultSalesRange();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: init,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );

    if (picked != null) {
      final normalized = viewModel.normalizePickerRange(picked);
      viewModel.setRange(normalized);
    }
  }
}
