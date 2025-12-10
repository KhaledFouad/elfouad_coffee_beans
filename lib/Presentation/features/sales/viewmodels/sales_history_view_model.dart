import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../data/repositories/sales_history_repository.dart';
import '../models/sale_record.dart';
import '../models/sales_day_group.dart';
import '../utils/sale_utils.dart';

class SalesHistoryState {
  const SalesHistoryState({
    required this.groups,
    required this.range,
    required this.allRecords,
    required this.fullTotalsByDay,
  });

  final List<SalesDayGroup> groups;
  final DateTimeRange range;
  final List<SaleRecord> allRecords;

  /// إجمالي المبيعات الحقيقي لكل يوم في الرينج
  /// key = label بتاع اليوم (مثلاً "2025-12-08")
  final Map<String, double> fullTotalsByDay;

  bool get isEmpty => allRecords.isEmpty;

  SalesHistoryState copyWith({
    List<SalesDayGroup>? groups,
    DateTimeRange? range,
    List<SaleRecord>? allRecords,
    Map<String, double>? fullTotalsByDay,
  }) {
    return SalesHistoryState(
      groups: groups ?? this.groups,
      range: range ?? this.range,
      allRecords: allRecords ?? this.allRecords,
      fullTotalsByDay: fullTotalsByDay ?? this.fullTotalsByDay,
    );
  }
}

class SalesHistoryViewModel extends ChangeNotifier {
  SalesHistoryViewModel({required SalesHistoryRepository repository})
    : _repository = repository,
      _state = SalesHistoryState(
        groups: const [],
        range: defaultSalesRange(),
        allRecords: const [],
        fullTotalsByDay: const {},
      );

  final SalesHistoryRepository _repository;

  SalesHistoryState _state;
  SalesHistoryState get state => _state;

  bool _isLoadingFirst = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isRangeTotalLoading = true;

  bool get isLoadingFirst => _isLoadingFirst;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isRangeTotalLoading => _isRangeTotalLoading;

  DateTimeRange? _customRange;

  bool get isFiltered => _customRange != null;
  DateTimeRange? get customRange => _customRange;

  DateTimeRange get activeRange => _customRange ?? defaultSalesRange();

  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  Future<void> initialize() async {
    await _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    _isLoadingFirst = true;
    _isLoadingMore = false;
    _hasMore = true;
    _isRangeTotalLoading = true;
    _lastDoc = null;
    notifyListeners();

    final range = activeRange;

    // أول صفحة للـ List
    final page = await _repository.fetchPage(range: range, startAfter: null);

    _lastDoc = page.lastDoc;
    _hasMore = page.hasMore;

    final records = page.docs.map(SaleRecord.new).toList();

    _state = SalesHistoryState(
      groups: _buildGroups(records, range),
      range: range,
      allRecords: records,
      fullTotalsByDay: const {},
    );

    _isLoadingFirst = false;
    notifyListeners();

    // احسب إجماليات كل يوم في الخلفية
    _loadFullTotalsPerDay(range);
  }

  /// بيحسب إجمالي المبيعات لكل يوم في الرينج كله (بدون Limit)
  Future<void> _loadFullTotalsPerDay(DateTimeRange range) async {
    try {
      _isRangeTotalLoading = true;
      notifyListeners();

      final docs = await _repository.fetchAllForRange(range: range);
      final records = docs.map(SaleRecord.new).toList();

      // نستخدم نفس المنطق بتاع grouping علشان نحسب per-day totals
      final Map<String, List<SaleRecord>> grouped = {};
      for (final record in records) {
        final effective = record.effectiveTime;
        final shifted = shiftDayByFourHours(effective);
        final key =
            '${shifted.year}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')}';
        grouped.putIfAbsent(key, () => <SaleRecord>[]).add(record);
      }

      final Map<String, double> totals = {};
      grouped.forEach((key, list) {
        totals[key] = _sumPaidOnly(list);
      });

      _state = _state.copyWith(fullTotalsByDay: totals);
    } finally {
      _isRangeTotalLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    final range = activeRange;
    final page = await _repository.fetchPage(
      range: range,
      startAfter: _lastDoc,
    );

    _lastDoc = page.lastDoc;
    _hasMore = page.hasMore;

    final moreRecords = page.docs.map(SaleRecord.new).toList();

    final existing = List<SaleRecord>.from(_state.allRecords);
    final existingIds = existing.map((e) => e.id).toSet();
    for (final r in moreRecords) {
      if (!existingIds.contains(r.id)) {
        existing.add(r);
      }
    }

    _state = _state.copyWith(
      allRecords: existing,
      groups: _buildGroups(existing, range),
    );

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> setRange(DateTimeRange? range) async {
    _customRange = range;
    await _loadFirstPage();
  }

  DateTimeRange normalizePickerRange(DateTimeRange picked) {
    final start = DateTime(
      picked.start.year,
      picked.start.month,
      picked.start.day,
      4,
    );
    final endBase = DateTime(
      picked.end.year,
      picked.end.month,
      picked.end.day,
      4,
    );
    return DateTimeRange(
      start: start,
      end: endBase.add(const Duration(days: 1)),
    );
  }

  Future<void> settleDeferredSale(String saleId) {
    return _repository.settleDeferredSale(saleId);
  }

  List<SalesDayGroup> _buildGroups(
    List<SaleRecord> records,
    DateTimeRange range,
  ) {
    final start = range.start;
    final end = range.end;

    bool inRange(DateTime value) {
      return !value.isBefore(start) && value.isBefore(end);
    }

    final filtered = <SaleRecord>[];
    for (final record in records) {
      final include =
          inRange(record.createdAt) ||
          (record.isDeferred && !record.isPaid) ||
          (record.isPaid &&
              record.settledAt != null &&
              inRange(record.settledAt!));
      if (include) {
        filtered.add(record);
      }
    }

    final Map<String, List<SaleRecord>> grouped = {};
    for (final record in filtered) {
      final effective = record.effectiveTime;
      final shifted = shiftDayByFourHours(effective);
      final key =
          '${shifted.year}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => <SaleRecord>[]).add(record);
    }

    final dayKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final groups = dayKeys.map((key) {
      final entries = grouped[key]!;
      final totalPaid = _sumPaidOnly(entries);
      return SalesDayGroup(label: key, entries: entries, totalPaid: totalPaid);
    }).toList();

    return groups;
  }

  double _sumPaidOnly(List<SaleRecord> entries) {
    double sum = 0;
    for (final entry in entries) {
      if (!entry.isComplimentary && entry.isPaid) {
        sum += entry.totalPrice;
      }
    }
    return sum;
  }
}
